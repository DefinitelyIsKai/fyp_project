const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

function parseIntFromFirestore(value) {
  if (value == null) return 0;
  if (typeof value === "number") return Math.floor(value);
  if (typeof value === "string") {
    const parsed = parseInt(value, 10);
    return isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

async function getPostTitle(postId) {
  try {
    const postDoc = await db.collection("posts").doc(postId).get();
    if (postDoc.exists) {
      return postDoc.data()?.title || "Unknown Post";
    }
    return "Unknown Post";
  } catch (error) {
    console.error(`Error getting post title for ${postId}:`, error);
    return "Unknown Post";
  }
}

async function deductPostCreationCredits(userId, postId, feeCredits = 200) {
  const walletDoc = db.collection("wallets").doc(userId);
  const txnCol = walletDoc.collection("transactions");

  try {
    const postTitle = await getPostTitle(postId);

    const onHoldTransactions = await txnCol
        .where("referenceId", "==", postId)
        .where("type", "==", "debit")
        .get();

    let onHoldTxnId = null;
    for (const doc of onHoldTransactions.docs) {
      const desc = doc.data().description || "";
      if (desc.includes("Post creation fee (On Hold)")) {
        onHoldTxnId = doc.id;
        break;
      }
    }

    if (onHoldTxnId != null) {
      const allPostTransactions = await txnCol
          .where("referenceId", "==", postId)
          .get();
      const alreadyProcessed = allPostTransactions.docs.some((doc) => {
        const data = doc.data();
        return (
          data.parentTxnId === onHoldTxnId &&
          data.type === "debit" &&
          !(data.description || "").includes("(On Hold)")
        );
      });
      if (alreadyProcessed) {
        console.log("Transaction already processed, skipping duplicate deduction");
        return true;
      }
    }

    await db.runTransaction(async (tx) => {
      const walletSnap = await tx.get(walletDoc);
      if (!walletSnap.exists) {
        throw new Error(`Wallet not found for user ${userId}`);
      }

      const walletData = walletSnap.data();
      const currentBalance = parseIntFromFirestore(walletData.balance);
      const currentHeldCredits = parseIntFromFirestore(walletData.heldCredits);

      if (currentHeldCredits < feeCredits) {
        console.warn(
            `Warning: heldCredits (${currentHeldCredits}) is less than ` +
            `feeCredits (${feeCredits}). This may indicate duplicate processing.`
        );
      }

      const newBalance = currentBalance - feeCredits;
      const newHeldCredits = Math.max(0, currentHeldCredits - feeCredits);

      tx.update(walletDoc, {
        balance: newBalance,
        heldCredits: newHeldCredits,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const newTxnRef = txnCol.doc();
      const description = postTitle !== "Unknown Post"
          ? `Post creation fee - ${postTitle}`
          : "Post creation fee";

      const txnData = {
        id: newTxnRef.id,
        userId: userId,
        type: "debit",
        amount: feeCredits,
        description: description,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        referenceId: postId,
      };

      if (onHoldTxnId != null) {
        txnData.parentTxnId = onHoldTxnId;
      }

      tx.set(newTxnRef, txnData);
    });

    return true;
  } catch (error) {
    console.error(`Error deducting credits for post ${postId}:`, error);
    return false;
  }
}

async function sendPostApprovalNotification(userId, postId, postTitle) {
  try {
    await db.collection("notifications").add({
      title: "Post published",
      body: `"${postTitle}" is now live.`,
      category: "post",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
      userId: userId,
      metadata: {
        postId: postId,
        postTitle: postTitle,
        actionType: "post_approved",
      },
    });
  } catch (error) {
    console.error(`Error sending approval notification:`, error);
  }
}

async function sendUnsuspensionNotification(userId, userName, userEmail) {
  try {
    await db.collection("notifications").add({
      title: "Account Access Restored",
      body: "Your account suspension has been lifted. You can now access all features normally.",
      category: "account_unsuspension",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
      userId: userId,
      metadata: {
        userName: userName,
        userEmail: userEmail,
        actionType: "unsuspension",
      },
    });
  } catch (error) {
    console.error(`Error sending unsuspension notification:`, error);
  }
}

async function unsuspendUser(userId) {
  await db.collection("users").doc(userId).update({
    status: "Active",
    isActive: true,
    suspendedAt: admin.firestore.FieldValue.delete(),
    suspensionReason: admin.firestore.FieldValue.delete(),
    suspensionDuration: admin.firestore.FieldValue.delete(),
  });
}

exports.autoApprovePendingPosts = functions
    .runWith({
      timeoutSeconds: 540,
      memory: "512MB",
    })
    .https.onCall(async (data, context) => {
      try {
        console.log("autoApprovePendingPosts: Function started");
        const now = new Date();
        const twoDaysFromNow = new Date(now);
        twoDaysFromNow.setDate(now.getDate() + 2);
        console.log(`autoApprovePendingPosts: Checking posts with eventStartDate <= ${twoDaysFromNow.toISOString()}`);

        const snapshot = await db.collection("posts")
            .where("status", "==", "pending")
            .where("isDraft", "==", false)
            .get();
        
        console.log(`autoApprovePendingPosts: Found ${snapshot.docs.length} pending posts`);

        let approvedCount = 0;
        const errors = [];
        const postsToApprove = [];

        for (const doc of snapshot.docs) {
          const postData = doc.data();
          const eventStartDate = postData.eventStartDate;
          const ownerId = postData.ownerId;

          if (!eventStartDate || !ownerId) continue;

          let startDate;
          if (eventStartDate.toDate) {
            startDate = eventStartDate.toDate();
          } else if (eventStartDate instanceof Date) {
            startDate = eventStartDate;
          } else {
            continue;
          }

          const startDateOnly = new Date(
              startDate.getFullYear(),
              startDate.getMonth(),
              startDate.getDate()
          );
          const twoDaysFromNowOnly = new Date(
              twoDaysFromNow.getFullYear(),
              twoDaysFromNow.getMonth(),
              twoDaysFromNow.getDate()
          );

          if (startDateOnly <= twoDaysFromNowOnly) {
            console.log(`autoApprovePendingPosts: Post ${doc.id} eligible (eventStartDate: ${startDate.toISOString()})`);
            postsToApprove.push({
              postId: doc.id,
              postData: postData,
              ownerId: ownerId,
            });
          } else {
            console.log(`autoApprovePendingPosts: Post ${doc.id} not eligible (eventStartDate: ${startDate.toISOString()} > ${twoDaysFromNowOnly.toISOString()})`);
          }
        }
        
        console.log(`autoApprovePendingPosts: ${postsToApprove.length} posts to approve`);

        let batch = db.batch();
        let batchCount = 0;
        const BATCH_LIMIT = 500;

        for (const post of postsToApprove) {
          try {
            const postId = post.postId;
            const postTitle = post.postData.title || "Unknown Post";
            const ownerId = post.ownerId;

            const postRef = db.collection("posts").doc(postId);
            batch.update(postRef, {
              status: "active",
              approvedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            batchCount++;
            approvedCount++;

            if (batchCount >= BATCH_LIMIT) {
              await batch.commit();
              batch = db.batch();
              batchCount = 0;
            }

            const creditSuccess = await deductPostCreationCredits(
                ownerId,
                postId,
                200
            );

            if (!creditSuccess) {
              console.warn(`Failed to deduct credits for post ${postId}`);
            }

            await sendPostApprovalNotification(ownerId, postId, postTitle);

            try {
              await db.collection("logs").add({
                actionType: "post_approved",
                postId: postId,
                postTitle: postTitle,
                ownerId: ownerId,
                previousStatus: "pending",
                newStatus: "active",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                createdBy: "auto_approve_system",
                autoApproved: true,
              });
            } catch (logError) {
              console.error("Error creating approval log entry:", logError);
            }
          } catch (error) {
            errors.push({
              postId: post.postId,
              error: error.message,
            });
            console.error(`Error auto-approving post ${post.postId}:`, error);
          }
        }

        if (batchCount > 0) {
          await batch.commit();
        }

        console.log(
            `Auto-approved ${approvedCount} post(s). Errors: ${errors.length}`
        );

        return {
          success: true,
          approvedCount: approvedCount,
          errors: errors.length > 0 ? errors : null,
          message: `Successfully auto-approved ${approvedCount} post(s)`,
        };
      } catch (error) {
        console.error("Error in autoApprovePendingPosts:", error);
        throw new functions.https.HttpsError(
            "internal",
            "An error occurred while auto-approving posts",
            error.message,
        );
      }
    });

exports.autoUnsuspendExpiredUsers = functions
    .runWith({
      timeoutSeconds: 540,
      memory: "512MB",
    })
    .https.onCall(async (data, context) => {
      try {
        console.log("autoUnsuspendExpiredUsers: Function started");
        const now = new Date();
        console.log(`autoUnsuspendExpiredUsers: Current time: ${now.toISOString()}`);
        let unsuspendedCount = 0;
        const errors = [];
        const usersToUnsuspend = [];

        const snapshot = await db.collection("users")
            .where("status", "==", "Suspended")
            .where("isActive", "==", false)
            .get();
        
        console.log(`autoUnsuspendExpiredUsers: Found ${snapshot.docs.length} suspended users`);

        for (const doc of snapshot.docs) {
          const userData = doc.data();
          const suspendedAt = userData.suspendedAt;
          const suspensionDuration = userData.suspensionDuration;
          const userId = doc.id;

          if (!suspendedAt || !suspensionDuration) {
            console.log(`Skipping user ${userId} - missing suspendedAt or suspensionDuration`);
            continue;
          }

          let suspensionDate;
          if (suspendedAt.toDate) {
            suspensionDate = suspendedAt.toDate();
          } else if (suspendedAt instanceof Date) {
            suspensionDate = suspendedAt;
          } else {
            continue;
          }

          const expirationDate = new Date(suspensionDate);
          expirationDate.setDate(expirationDate.getDate() + suspensionDuration);

          if (now >= expirationDate) {
            console.log(`autoUnsuspendExpiredUsers: User ${userId} eligible (expired: ${expirationDate.toISOString()})`);
            usersToUnsuspend.push({
              userId: userId,
              userData: userData,
            });
          } else {
            console.log(`autoUnsuspendExpiredUsers: User ${userId} not expired yet (expires: ${expirationDate.toISOString()})`);
          }
        }
        
        console.log(`autoUnsuspendExpiredUsers: ${usersToUnsuspend.length} users to unsuspend`);

        let batch = db.batch();
        let batchCount = 0;
        const BATCH_LIMIT = 500;

        for (const user of usersToUnsuspend) {
          try {
            const userId = user.userId;
            const userName = user.userData.fullName || "User";
            const userEmail = user.userData.email || "";

            const userRef = db.collection("users").doc(userId);
            batch.update(userRef, {
              status: "Active",
              isActive: true,
              suspendedAt: admin.firestore.FieldValue.delete(),
              suspensionReason: admin.firestore.FieldValue.delete(),
              suspensionDuration: admin.firestore.FieldValue.delete(),
            });

            batchCount++;
            unsuspendedCount++;

            if (batchCount >= BATCH_LIMIT) {
              await batch.commit();
              batch = db.batch();
              batchCount = 0;
            }

            await sendUnsuspensionNotification(userId, userName, userEmail);

            try {
              await db.collection("logs").add({
                actionType: "user_unsuspended",
                userId: userId,
                userName: userName,
                previousStatus: "Suspended",
                newStatus: "Active",
                reason: "Automatic unsuspension: Suspension period expired",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                createdBy: "auto_unsuspend_system",
                autoUnsuspended: true,
              });
            } catch (logError) {
              console.error("Error creating unsuspension log entry:", logError);
            }
          } catch (error) {
            errors.push({
              userId: user.userId,
              error: error.message,
            });
            console.error(`Error auto-unsuspending user ${user.userId}:`, error);
          }
        }

        if (batchCount > 0) {
          await batch.commit();
        }

        console.log(
            `Auto-unsuspended ${unsuspendedCount} user(s). Errors: ${errors.length}`
        );

        return {
          success: true,
          unsuspendedCount: unsuspendedCount,
          errors: errors.length > 0 ? errors : null,
          message: `Successfully auto-unsuspended ${unsuspendedCount} user(s)`,
        };
      } catch (error) {
        console.error("Error in autoUnsuspendExpiredUsers:", error);
        throw new functions.https.HttpsError(
            "internal",
            "An error occurred while auto-unsuspending users",
            error.message,
        );
      }
    });

exports.autoCompleteExpiredPosts = functions
    .runWith({
      timeoutSeconds: 540,
      memory: "512MB",
    })
    .https.onCall(async (data, context) => {
      try {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    let completedCount = 0;
    const errors = [];

    const snapshot = await db.collection("posts")
        .where("status", "==", "active")
        .where("isDraft", "==", false)
        .get();

    let batch = db.batch();
    let batchCount = 0;
    const BATCH_LIMIT = 500;

    for (const doc of snapshot.docs) {
      const postData = doc.data();
      const eventEndDate = postData.eventEndDate;

      if (!eventEndDate) continue;

      let endDate;
      if (eventEndDate.toDate) {
        endDate = eventEndDate.toDate();
      } else if (eventEndDate instanceof Date) {
        endDate = eventEndDate;
      } else {
        continue; 
      }

      const endDateOnly = new Date(
          endDate.getFullYear(),
          endDate.getMonth(),
          endDate.getDate()
      );

      if (today >= endDateOnly) {
        try {
          const postRef = db.collection("posts").doc(doc.id);
          batch.update(postRef, {
            status: "completed",
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          batchCount++;
          completedCount++;

         
          if (batchCount >= BATCH_LIMIT) {
            await batch.commit();
            batch = db.batch(); 
            batchCount = 0;
          }
        } catch (error) {
          errors.push({
            postId: doc.id,
            error: error.message,
          });
        }
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    return {
      success: true,
      completedCount: completedCount,
      errors: errors.length > 0 ? errors : null,
      message: `Successfully completed ${completedCount} expired post(s)`,
    };
  } catch (error) {
    console.error("Error in autoCompleteExpiredPosts:", error);
    throw new functions.https.HttpsError(
        "internal",
        "An error occurred while completing expired posts",
        error.message,
    );
  }
});


