<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
session_start();
require_once '/home/v6gkv3hx0rj5/vendor/autoload.php';

/* ------------------------------------------------------
   CONFIGURATION
------------------------------------------------------- */
$db_server = "localhost";
$db_user   = "awarcrownadmins";
$db_pass   = "Awarcrown@0523";
$db_name   = "awarcrown";

$logoUrl     = "https://www.awarcrown.com/images/black_logo.png";
$linkedinUrl = "https://www.linkedin.com/company/cybertron7";


/* ------------------------------------------------------
   HELPER: SAFE SANITIZE
------------------------------------------------------- */
function clean($value) {
    return htmlspecialchars(trim($value), ENT_QUOTES, 'UTF-8');
}


/* ------------------------------------------------------
   ERROR PAGE HELPER
------------------------------------------------------- */
function showError($msg, $details = "") {
    global $logoUrl;

    echo "
    <html><head><meta name='viewport' content='width=device-width, initial-scale=1'>
    <style>
        body {
            font-family: Arial;
            background:#f3f3f3;
            display:flex;
            justify-content:center;
            align-items:center;
            height:100vh;
            margin:0;
        }
        .box {
            background:#fff;
            padding:25px;
            width:90%;
            max-width:420px;
            border-radius:14px;
            text-align:center;
            box-shadow:0 4px 15px rgba(0,0,0,0.09);
        }
        .box.error { border-top:6px solid #dc3545; }
        .logo { width:80px; margin-bottom:10px; }
        p { color:#444; font-size:15px; }
        small { color:#888; }
        button {
            padding:10px 18px;
            border:none;
            background:#333;
            color:white;
            border-radius:8px;
            margin-top:12px;
        }
    </style></head><body>
        <div class='box error'>
            <img src='$logoUrl' class='logo'>
            <h2> Something Went Wrong</h2>
            <p>$msg</p>
            " . ($details ? "<small>$details</small>" : "") . "
            <br><br>
            <button onclick='window.history.back()'>Go Back</button>
        </div>
    </body></html>";
    exit;
}


/* ------------------------------------------------------
   DB CONNECTION
------------------------------------------------------- */
$conn = new mysqli($db_server, $db_user, $db_pass, $db_name);
if ($conn->connect_error) {
    showError("Database connection failed.", $conn->connect_error);
}


/* ------------------------------------------------------
   GET POST INPUT
------------------------------------------------------- */
$name         = isset($_POST['name']) ? clean($_POST['name']) : null;
$email        = isset($_POST['email']) ? clean($_POST['email']) : null;
$feedbackType = isset($_POST['feedbackType']) ? clean($_POST['feedbackType']) : null;
$message      = isset($_POST['message']) ? clean($_POST['message']) : null;

if (!$name || !$email || !$feedbackType || !$message) {
    showError("Please fill all required fields.");
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    showError("Invalid email address.");
}


/* ------------------------------------------------------
   TICKET ID
------------------------------------------------------- */
$ticketID = "AWC-" . strtoupper(bin2hex(random_bytes(4)));



/* ------------------------------------------------------
   SAVE FEEDBACK IN DATABASE
------------------------------------------------------- */
$stmt = $conn->prepare("
    INSERT INTO feedback (name, email, feedback_type, message, ticket_id)
    VALUES (?, ?, ?, ?, ?)
");
if (!$stmt) showError("Database prepare failed", $conn->error);

$stmt->bind_param("sssss", $name, $email, $feedbackType, $message, $ticketID);
if (!$stmt->execute()) showError("Failed to save feedback", $stmt->error);



/* ------------------------------------------------------
   SEND EMAIL USING PHPMailer (LOCALHOST PORT 25)
------------------------------------------------------- */

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;



$mail = new PHPMailer(true);

$emailBody = "
<html><body style='font-family: Arial, sans-serif;'>
    <h2>Hello $name,</h2>

    <p>Thank you for reporting an issue from the <strong>Ideaship App</strong>.</p>
    <p>Your ticket has been logged successfully.</p>

    <p><strong>Ticket ID:</strong> $ticketID<br>
       <strong>Category:</strong> $feedbackType</p>

    <p>Our engineering team will check your report and work on a fix if needed.</p>

    <hr style='border:0; border-top:1px solid #ccc; margin:25px 0;'>

    <p style='font-size:13px; color:#666;'>
        © " . date("Y") . " Awarcrown Corporations LLP — All Rights Reserved.<br>
        
    </p>
</body></html>
";

try {
    $mail->isSMTP();
    $mail->Host = "localhost";
    $mail->Port = 25;
    $mail->SMTPAuth = false;
    $mail->SMTPSecure = false;

    $mail->setFrom("support@awarcrown.com", "Awarcrown Support");
    $mail->addAddress($email);
    $mail->addBCC("adityach0523@gmail.com");
    $mail->addBCC("naveenjupalli1019@gmail.com");
    $mail->addBCC("alapatijanardhan19254@gmail.com");

    $mail->isHTML(true);
    $mail->Subject = "Ideaship Support Ticket Created - #$ticketID";
    $mail->Body = $emailBody;

    $mail->send();
    $mailStatus = true;

} catch (Exception $e) {
    $mailStatus = false;
    error_log("MAIL ERROR: " . $mail->ErrorInfo);
}



/* ------------------------------------------------------
   SUCCESS PAGE WITH LOADING & DEEP LINK REDIRECT
------------------------------------------------------- */
echo "
<html>
<head>
<meta name='viewport' content='width=device-width, initial-scale=1'>

<style>
    body {
        margin:0;
        background:#eef1f5;
        font-family: 'Segoe UI', Arial;
        height:100vh;
        display:flex;
        justify-content:center;
        align-items:center;
        flex-direction:column;
        text-align:center;
        padding:20px;
    }

    .box {
        background:#fff;
        width:95%;
        max-width:430px;
        padding:25px;
        border-radius:16px;
        box-shadow:0 8px 20px rgba(0,0,0,0.1);
        animation: fadeIn 0.6s ease;
    }

    .success { border-top:6px solid #28a745; }
    .logo { width:90px; }
    p { color:#444; font-size:16px; }

    @keyframes fadeIn {
        from { opacity:0; transform:translateY(-20px); }
        to { opacity:1; transform:translateY(0); }
    }

    /* Circular Loader */
    .loader {
        margin:20px auto;
        border:6px solid #f3f3f3;
        border-top:6px solid #28a745;
        border-radius:50%;
        width:55px;
        height:55px;
        animation:spin 1s linear infinite;
    }
    @keyframes spin {
        0% { transform:rotate(0deg); }
        100% { transform:rotate(360deg); }
    }
</style>

</head>
<body>

<div class='box success'>
    <img src='$logoUrl' class='logo'>
    <h2>Thank You!</h2>
    <p>Your ticket has been created successfully.</p>
    <p><strong>Ticket ID:</strong> $ticketID</p>
    <p>Opening Ideaship App…</p>
     <p style='font-size:13px; color:#666;'>
        © " . date("Y") . " Awarcrown Corporations LLP — All Rights Reserved.<br>
        
    </p>

    <div class='loader'></div>
</div>

<script>
    // Try opening app
    setTimeout(() => { window.location.href = 'awarcrown://open'; }, 15000);

    // Fallback: Play Store → Website
    setTimeout(() => {
        if (/Android/i.test(navigator.userAgent)) {
            window.location.href = 'https://play.google.com/store/apps/details?id=com.awarcrown.ideaship';
        } else {
            window.location.href = 'https://www.awarcrown.com';
        }
    }, 6000);
</script>

</body>
</html>
";

$stmt->close();
$conn->close();
?>
