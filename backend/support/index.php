<?php


function decryptAES($encryptedBase64) {
    $key = "1234567890123456";
    $iv  = "6543210987654321";

    // Step 1: URL decode
    $encryptedBase64 = urldecode($encryptedBase64);

    // Step 2: Replace spaces with '+' (Apache sometimes breaks this)
    $encryptedBase64 = str_replace(' ', '+', $encryptedBase64);

    // Step 3: Base64 decode
    $ciphertext = base64_decode($encryptedBase64);

    // Step 4: AES decrypt
    return openssl_decrypt(
        $ciphertext,
        "AES-128-CBC",
        $key,
        OPENSSL_RAW_DATA,
        $iv
    );
}

// Read values from URL
$encName  = $_GET['n'] ?? "";
$encEmail = $_GET['e'] ?? "";
if (empty($encName) || empty($encEmail)) {
    echo "
    <html>
    <head>
        <meta name='viewport' content='width=device-width, initial-scale=1'>

        <style>
            body {
                margin:0;
                font-family:Arial, sans-serif;
                background:#f7f7f7;
                height:100vh;
                display:flex;
                justify-content:center;
                align-items:center;
                text-align:center;
                padding:20px;
            }
            .container {
                background:white;
                padding:25px;
                border-radius:14px;
                width:90%;
                max-width:400px;
                box-shadow:0 8px 20px rgba(0,0,0,0.08);
            }
            h2 { margin-bottom:10px; }
            p { color:#444; font-size:15px; }

            /* Circular loader */
            .loader {
                margin:20px auto;
                border:5px solid #eaeaea;
                border-top:5px solid #28a745;
                border-radius:50%;
                width:50px;
                height:50px;
                animation:spin 1s linear infinite;
            }
            @keyframes spin {
                0% { transform:rotate(0deg); }
                100% { transform:rotate(360deg); }
            }
        </style>
    </head>

    <body>

        <div class='container'>
            <h2>Redirecting…</h2>
            <p>Opening the Ideaship app. Please wait.</p>
            <div class='loader'></div>
        </div>

        <script>
            alert('Missing required fields. No worries, we will redirect you to our application.');

            const isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);

            if (isMobile) {
                // Try deep link
                window.location.href = 'awarcrown://open';

                // Fallback after 2.2 seconds
                setTimeout(() => {
                    if (/Android/i.test(navigator.userAgent)) {
                        window.location.href = 'https://play.google.com/store/apps/details?id=com.awarcrown.ideaship';
                    } else {
                        window.location.href = 'https://ideaship.awarcrown.com';
                    }
                }, 2200);

            } else {
                // Desktop fallback
                setTimeout(() => {
                    window.location.href = 'https://www.awarcrown.com';
                }, 1500);
            }
        </script>

    </body>
    </html>
    ";
    exit;
}




$name  = decryptAES($encName);
$email = decryptAES($encEmail);


?>


<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Feedback Form</title>
    <link rel="icon" href="https://awarcrown.com/images/black_logo.png" />
    <link rel="stylesheet" href="feedback.css">
    <script src="feedback.js" defer></script>

    <!-- Google tag (gtag.js) -->
    <script async src="https://www.googletagmanager.com/gtag/js?id=G-BEMBT4ENS1"></script>
    <script>
        window.dataLayer = window.dataLayer || [];
        function gtag(){ dataLayer.push(arguments); }
        gtag('js', new Date());
        gtag('config', 'G-BEMBT4ENS1');
    </script>

    <style>
        .loading-screen {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(255, 255, 255, 0.8);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 9999;
        }
        .loading-screen img {
            width: 200px;
            height: 200px;
        }
    </style>
</head>

<body>
    <div class="loading-screen" id="loading-screen">
        <img src="https://awarcrown.com/images/newload.gif" alt="Loading">
    </div>

    <div class="container">
        <h1>Awarcrown Corporations</h1>
        <h2>Support</h2>

        <form id="feedbackForm" action="feedbacksave" method="POST">
            
            <label for="name">Name:</label>
            <input type="text" id="name" name="name"  value="<?php echo $name; ?>" readonly>

            <label for="email">Email:</label>
            <input type="email" id="email" name="email" value="<?php echo $email; ?>" readonly>

            <label for="feedbackType">Ticket Type:</label>
            <select id="feedbackType" name="feedbackType" required>
                <option value="general">General Feedback</option>
                <option value="bug">Report a Bug</option>
                <option value="support">Support</option>
            </select>

            <label for="message">Message:</label>
            <textarea id="message" name="message" rows="4" required></textarea>

            <button type="submit">Submit</button>
            
        </form>

        <div id="responseMessage"></div>
    </div>

    <script>
        document.addEventListener("DOMContentLoaded", function () {
            const loadingScreen = document.getElementById("loading-screen");

            window.onload = function () {
                loadingScreen.style.display = "none";
            };

            document.getElementById("feedbackForm").addEventListener("submit", function () {
                loadingScreen.style.display = "flex";
            });
        });
    </script>
</body>
</html>
