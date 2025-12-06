const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();


exports.autoCompleteExpiredPosts = functions.https.onCall(async (data, context) => {


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
    //batch write limit

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

      //current date has passed or equals the event end date
      if (today >= endDateOnly) {
        try {
          //update status
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


