import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';

class EmailService {
  static const String _smtpHost = 'smtp.gmail.com';
  static const int _smtpPort = 587;
  static const String _senderEmail = 'lowbryan022@gmail.com'; 
  static const String _senderPassword = 'jcvsitkyjscsoyho'; 
  
 

  //approved
  Future<void> sendBookingApprovalEmail({
    required String recipientEmail,
    required String recipientName,
    required String recruiterName,
    required String slotDate,
    required String slotTime,
    required String jobTitle,
  }) async {
    try {
      
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        ssl: false, //STARTTLS
        allowInsecure: false,
        username: _senderEmail,
        password: _senderPassword,
      );

   
      final message = Message()
        ..from = Address(_senderEmail, 'JobSeek Team')
        ..recipients.add(recipientEmail)
        ..subject = 'Booking Approved - Interview Slot Confirmed for $jobTitle'
        ..html = _buildEmailHtml(
          recipientName: recipientName,
          recruiterName: recruiterName,
          slotDate: slotDate,
          slotTime: slotTime,
          jobTitle: jobTitle,
        )
        ..text = _buildEmailText(
          recipientName: recipientName,
          recruiterName: recruiterName,
          slotDate: slotDate,
          slotTime: slotTime,
          jobTitle: jobTitle,
        );

     
      debugPrint('Attempting to send email via SMTP...');
      debugPrint('SMTP Host: $_smtpHost');
      debugPrint('SMTP Port: $_smtpPort');
      debugPrint('Sender Email: $_senderEmail');
      
      final sendReport = await send(message, smtpServer);
      
      debugPrint('Email sent successfully to $recipientEmail');
      debugPrint('Send report: ${sendReport.toString()}');
    } catch (e) {
      debugPrint('Error sending booking approval email: $e');
      debugPrint('Error details: ${e.toString()}');
    }
  }

  String _buildEmailHtml({
    required String recipientName,
    required String recruiterName,
    required String slotDate,
    required String slotTime,
    required String jobTitle,
  }) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
          }
          .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
          }
          .header {
            background-color: #00C8A0;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 8px 8px 0 0;
          }
          .content {
            background-color: #f9f9f9;
            padding: 30px;
            border-radius: 0 0 8px 8px;
          }
          .info-box {
            background-color: white;
            padding: 20px;
            margin: 20px 0;
            border-radius: 8px;
            border-left: 4px solid #00C8A0;
          }
          .info-item {
            margin: 10px 0;
          }
          .info-label {
            font-weight: bold;
            color: #666;
          }
          .footer {
            text-align: center;
            margin-top: 20px;
            color: #666;
            font-size: 12px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Booking Approved!</h1>
          </div>
          <div class="content">
            <p>Dear $recipientName,</p>
            <p>Great news! Your booking request has been approved by <strong>$recruiterName</strong>.</p>
            
            <div class="info-box">
              <h3>Interview Details</h3>
              <div class="info-item">
                <span class="info-label">Job Position:</span> $jobTitle
              </div>
              <div class="info-item">
                <span class="info-label">Date:</span> $slotDate
              </div>
              <div class="info-item">
                <span class="info-label">Time:</span> $slotTime
              </div>
              <div class="info-item">
                <span class="info-label">Recruiter:</span> $recruiterName
              </div>
            </div>
            
            <p>Please make sure to be available at the scheduled time. If you need to reschedule or have any questions, please contact the recruiter through the app.</p>
            
            <p>We wish you the best of luck with your interview!</p>
            
            <p>Best regards,<br>The JobSeek Team</p>
          </div>
          <div class="footer">
            <p>This is an automated email. Please do not reply to this message.</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  String _buildEmailText({
    required String recipientName,
    required String recruiterName,
    required String slotDate,
    required String slotTime,
    required String jobTitle,
  }) {
    return '''
      Booking Approved!
      
      Dear $recipientName,
      
      Great news! Your booking request has been approved by $recruiterName.
      
      Interview Details:
      - Job Position: $jobTitle
      - Date: $slotDate
      - Time: $slotTime
      - Recruiter: $recruiterName
      
      Please make sure to be available at the scheduled time. If you need to reschedule or have any questions, please contact the recruiter through the app.
      
      We wish you the best of luck with your interview!
      
      Best regards,
      The JobSeek Team
    ''';
  }

 
  Future<void> sendBookingCancellationEmail({
    required String recipientEmail,
    required String recipientName,
    required String recruiterName,
    required String slotDate,
    required String slotTime,
    required String jobTitle,
  }) async {
    try {
      //SMTP configuration
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        ssl: false, //STARTTLS
        allowInsecure: false,
        username: _senderEmail,
        password: _senderPassword,
      );

      //create  message
      final message = Message()
        ..from = Address(_senderEmail, 'JobSeek Team')
        ..recipients.add(recipientEmail)
        ..subject = 'Booking Cancelled - Interview Slot Removed for $jobTitle'
        ..html = _buildCancellationEmailHtml(
          recipientName: recipientName,
          recruiterName: recruiterName,
          slotDate: slotDate,
          slotTime: slotTime,
          jobTitle: jobTitle,
        )
        ..text = _buildCancellationEmailText(
          recipientName: recipientName,
          recruiterName: recruiterName,
          slotDate: slotDate,
          slotTime: slotTime,
          jobTitle: jobTitle,
        );

    
      debugPrint('Attempting to send cancellation email via SMTP...');
      debugPrint('SMTP Host: $_smtpHost');
      debugPrint('SMTP Port: $_smtpPort');
      debugPrint('Sender Email: $_senderEmail');
      
      final sendReport = await send(message, smtpServer);
      
      debugPrint('Cancellation email sent successfully to $recipientEmail');
      debugPrint('Send report: ${sendReport.toString()}');
    } catch (e) {
      debugPrint('Error sending booking cancellation email: $e');
      debugPrint('Error details: ${e.toString()}');
    }
  }

  String _buildCancellationEmailHtml({
    required String recipientName,
    required String recruiterName,
    required String slotDate,
    required String slotTime,
    required String jobTitle,
  }) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
          }
          .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
          }
          .header {
            background-color: #FF6B6B;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 8px 8px 0 0;
          }
          .content {
            background-color: #f9f9f9;
            padding: 30px;
            border-radius: 0 0 8px 8px;
          }
          .info-box {
            background-color: white;
            padding: 20px;
            margin: 20px 0;
            border-radius: 8px;
            border-left: 4px solid #FF6B6B;
          }
          .info-item {
            margin: 10px 0;
          }
          .info-label {
            font-weight: bold;
            color: #666;
          }
          .warning-box {
            background-color: #FFF3CD;
            padding: 15px;
            margin: 20px 0;
            border-radius: 8px;
            border-left: 4px solid #FFC107;
          }
          .footer {
            text-align: center;
            margin-top: 20px;
            color: #666;
            font-size: 12px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Booking Cancelled</h1>
          </div>
          <div class="content">
            <p>Dear $recipientName,</p>
            <p>We regret to inform you that your booked interview slot has been cancelled by <strong>$recruiterName</strong>.</p>
            
            <div class="info-box">
              <h3>Cancelled Interview Details</h3>
              <div class="info-item">
                <span class="info-label">Job Position:</span> $jobTitle
              </div>
              <div class="info-item">
                <span class="info-label">Date:</span> $slotDate
              </div>
              <div class="info-item">
                <span class="info-label">Time:</span> $slotTime
              </div>
              <div class="info-item">
                <span class="info-label">Recruiter:</span> $recruiterName
              </div>
            </div>
            
            <div class="warning-box">
              <p><strong>What to do next:</strong></p>
              <p>Please contact the recruiter through the app to discuss alternative arrangements or reschedule your interview.</p>
            </div>
            
            <p>We apologize for any inconvenience this may cause. If you have any questions or concerns, please don't hesitate to reach out to the recruiter.</p>
            
            <p>Best regards,<br>The JobSeek Team</p>
          </div>
          <div class="footer">
            <p>This is an automated email. Please do not reply to this message.</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  String _buildCancellationEmailText({
    required String recipientName,
    required String recruiterName,
    required String slotDate,
    required String slotTime,
    required String jobTitle,
  }) {
    return '''
      Booking Cancelled
      
      Dear $recipientName,
      
      We regret to inform you that your booked interview slot has been cancelled by $recruiterName.
      
      Cancelled Interview Details:
      - Job Position: $jobTitle
      - Date: $slotDate
      - Time: $slotTime
      - Recruiter: $recruiterName
      
      What to do next:
      Please contact the recruiter through the app to discuss alternative arrangements or reschedule your interview.
      
      We apologize for any inconvenience this may cause. If you have any questions or concerns, please don't hesitate to reach out to the recruiter.
      
      Best regards,
      The JobSeek Team
    ''';
  }

  /// Send OTP email for admin login verification
  Future<void> sendOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otp,
  }) async {
    try {
      // Create SMTP server configuration
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        ssl: false, // Use STARTTLS, not SSL
        allowInsecure: false,
        username: _senderEmail,
        password: _senderPassword,
      );

      // Create email message
      final message = Message()
        ..from = Address(_senderEmail, 'JobSeek Admin Portal')
        ..recipients.add(recipientEmail)
        ..subject = 'Admin Login Verification Code'
        ..html = _buildOtpEmailHtml(
          recipientName: recipientName,
          otp: otp,
        )
        ..text = _buildOtpEmailText(
          recipientName: recipientName,
          otp: otp,
        );

      // Send email
      debugPrint('Attempting to send OTP email via SMTP...');
      debugPrint('SMTP Host: $_smtpHost');
      debugPrint('SMTP Port: $_smtpPort');
      debugPrint('Sender Email: $_senderEmail');
      
      final sendReport = await send(message, smtpServer);
      
      debugPrint('OTP email sent successfully to $recipientEmail');
      debugPrint('Send report: ${sendReport.toString()}');
    } catch (e) {
      debugPrint('Error sending OTP email: $e');
      debugPrint('Error details: ${e.toString()}');
      rethrow;
    }
  }

  String _buildOtpEmailHtml({
    required String recipientName,
    required String otp,
  }) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
          }
          .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
          }
          .header {
            background-color: #1E3A8A;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 8px 8px 0 0;
          }
          .content {
            background-color: #f9f9f9;
            padding: 30px;
            border-radius: 0 0 8px 8px;
          }
          .otp-box {
            background-color: white;
            padding: 30px;
            margin: 20px 0;
            border-radius: 8px;
            border: 2px dashed #1E3A8A;
            text-align: center;
          }
          .otp-code {
            font-size: 36px;
            font-weight: bold;
            color: #1E3A8A;
            letter-spacing: 8px;
            margin: 20px 0;
          }
          .warning-box {
            background-color: #FFF3CD;
            padding: 15px;
            margin: 20px 0;
            border-radius: 8px;
            border-left: 4px solid #FFC107;
          }
          .footer {
            text-align: center;
            margin-top: 20px;
            color: #666;
            font-size: 12px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Admin Login Verification</h1>
          </div>
          <div class="content">
            <p>Dear $recipientName,</p>
            <p>You have requested to log in to the JobSeek Admin Portal. Please use the following verification code to complete your login:</p>
            
            <div class="otp-box">
              <p style="margin: 0; color: #666; font-size: 14px;">Your verification code is:</p>
              <div class="otp-code">$otp</div>
              <p style="margin: 0; color: #666; font-size: 12px;">This code will expire in 10 minutes.</p>
            </div>
            
            <div class="warning-box">
              <p style="margin: 0;"><strong>Security Notice:</strong></p>
              <p style="margin: 5px 0 0 0;">If you did not request this code, please ignore this email or contact your system administrator immediately.</p>
            </div>
            
            <p>Please enter this code in the login page to complete your authentication.</p>
            
            <p>Best regards,<br>The JobSeek Admin Team</p>
          </div>
          <div class="footer">
            <p>This is an automated email. Please do not reply to this message.</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  String _buildOtpEmailText({
    required String recipientName,
    required String otp,
  }) {
    return '''
      Admin Login Verification
      
      Dear $recipientName,
      
      You have requested to log in to the JobSeek Admin Portal. Please use the following verification code to complete your login:
      
      Verification Code: $otp
      
      This code will expire in 10 minutes.
      
      Security Notice:
      If you did not request this code, please ignore this email or contact your system administrator immediately.
      
      Please enter this code in the login page to complete your authentication.
      
      Best regards,
      The JobSeek Admin Team
      
      ---
      This is an automated email. Please do not reply to this message.
    ''';
  }
}

