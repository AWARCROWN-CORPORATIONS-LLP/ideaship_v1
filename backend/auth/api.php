<?php
// === Security Headers ===
header("Access-Control-Allow-Origin: https://server.awarcrown.com");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');
header('Referrer-Policy: no-referrer');

// === Dependencies ===
require '/home/v6gkv3hx0rj5/vendor/autoload.php';
require_once 'config.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

// === PHPMailer Setup ===
$mail = new PHPMailer(true);
try {
    $mail->isSMTP();
    $mail->Host = 'localhost';
    $mail->Port = 25;
    $mail->SMTPAuth = false;
    $mail->SMTPSecure = false;
    $mail->Timeout = 15;
    $mail->CharSet = 'UTF-8';
    $mail->Encoding = 'base64';
    $mail->isHTML(false);
    $mail->setFrom('support@awarcrown.com', 'Awarcrown Auth');
    $mail->addReplyTo('support@awarcrown.com', 'Awarcrown Support');
} catch (Exception $e) {
    error_log("PHPMailer setup failed: " . $e->getMessage());
}

// === JWT Utils ===
function base64UrlEncode($text) {
    return str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($text));
}
function base64UrlDecode($text) {
    $text = strtr($text, '-_', '+/');
    $padding = strlen($text) % 4;
    if ($padding) $text .= str_repeat('=', 4 - $padding);
    return base64_decode($text);
}
function generateAccessToken($userId, $secret, $expiresIn = 3600) {
    $header = json_encode(['typ' => 'JWT', 'alg' => 'HS256']);
    $payload = json_encode(['user_id' => $userId, 'exp' => time() + $expiresIn]);
    $signature = hash_hmac('sha256', base64UrlEncode($header) . "." . base64UrlEncode($payload), $secret, true);
    return base64UrlEncode($header) . "." . base64UrlEncode($payload) . "." . base64UrlEncode($signature);
}

// === Logging + JSON Error Response ===
function logError($msg) {
    error_log(date('[Y-m-d H:i:s] ') . $msg . "\n", 3, __DIR__ . '/error.log');
}
function sendErrorResponse($status, $msg) {
    http_response_code($status);
    echo json_encode(['success' => false, 'message' => $msg]);
    exit;
}


function outputSuccessModal($msg) {
    echo '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Success</title>

<style>
    :root {
        --primary: #1a73e8;       /* Google Blue */
        --success: #0f9d58;       /* Google Green */
        --text-dark: #202124;
        --text-light: #5f6368;
        --bg: #f8f9fa;
        --border: #dadce0;
    }

    body {
        margin: 0;
        background: var(--bg);
        font-family: "Roboto", "Segoe UI", sans-serif;
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100vh;
        padding: 20px;
    }

    .card {
        background: #fff;
        width: 100%;
        max-width: 430px;
        padding: 40px 32px;
        border-radius: 14px;
        text-align: center;
        box-shadow: 0 6px 20px rgba(0,0,0,0.08);
        animation: fadeIn .5s ease-out;
    }

    .icon {
        font-size: 60px;
        margin-bottom: 10px;
        color: var(--success);
    }

    h2 {
        margin: 0;
        font-size: 28px;
        font-weight: 600;
        color: var(--text-dark);
        margin-bottom: 12px;
    }

    p {
        font-size: 16px;
        color: var(--text-light);
        line-height: 1.6;
    }

    .countdown {
        margin-top: 18px;
        font-size: 17px;
        font-weight: 500;
        color: var(--primary);
    }

    .button {
        display: inline-block;
        margin-top: 28px;
        padding: 12px 28px;
        background: var(--primary);
        color: #fff;
        border-radius: 8px;
        font-size: 15px;
        font-weight: 500;
        text-decoration: none;
        transition: background .25s;
    }

    .button:hover {
        background: #1669c1;
    }

    @keyframes fadeIn {
        from { opacity: 0; transform: translateY(15px); }
        to   { opacity: 1; transform: translateY(0); }
    }
</style>
</head>

<body>

<div class="card">
    <div class="icon">✔️</div>

    <h2>Success</h2>

    <p><?php echo htmlspecialchars($msg); ?></p>
    <p class="sub">Opening Awarcrown App…</p>

    <div class="countdown">
        Redirecting in <span id="count">5</span> seconds
    </div>

    <a href="awarcrown://verified" class="button">Open App Now</a>
</div>

<script>
let c = 5;
const timer = setInterval(() => {
    document.getElementById("count").innerText = --c;
    if (c <= 0) clearInterval(timer);
}, 1000);

setTimeout(() => {
    window.location = "awarcrown://verified";

    // fallback
    setTimeout(() => {
        window.location = "https://server.awarcrown.com";
    }, 5000);

}, 5000);
</script>

</body>
</html>
';
    exit;
}

////////////////////////////////////////////////////////////////
// ERROR MODAL (UPDATED: awarcrown://open + 5 sec wait only)
////////////////////////////////////////////////////////////////
function outputErrorModal($msg) {
    echo '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Error</title>
<style>
    body{
        font-family:"Segoe UI",sans-serif;
        background:linear-gradient(135deg,#ff416c,#ff4b2b);
        margin:0;padding:0;
        display:flex;justify-content:center;align-items:center;
        height:100vh;color:#fff;text-align:center;
    }
    .card{
        background:rgba(255,255,255,0.15);
        backdrop-filter:blur(15px);
        padding:40px;border-radius:20px;
        width:90%;max-width:420px;
        box-shadow:0 8px 25px rgba(0,0,0,0.2);
        animation:fadeIn .8s;
    }
    h2{font-size:30px;margin-bottom:10px;animation:pop .6s}
    p{font-size:16px;line-height:1.5}
    .sub{margin-top:10px;opacity:0.9;font-size:15px}
    .countdown{font-size:18px;font-weight:bold;margin-top:20px}

    @keyframes fadeIn{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:translateY(0)}}
    @keyframes pop{0%{transform:scale(0.5);opacity:0}100%{transform:scale(1);opacity:1}}
</style>
</head>

<body>
<div class="card">
    <h2>Error</h2>
    <p>' . htmlspecialchars($msg) . '</p>
    <p class="sub">You will be redirected securely…</p>
    <div class="countdown">Redirecting in <span id="count">5</span> seconds</div>
</div>

<script>
let c = 5;
const timer = setInterval(() => {
    c--;
    document.getElementById("count").innerText = c;
    if (c <= 0) clearInterval(timer);
}, 1000);

setTimeout(() => {
    window.location = "awarcrown://open";

    setTimeout(() => {
        window.location = "https://awarcrown.com";
    }, 5000);

}, 5000);
</script>

</body>
</html>';
    exit;
}
//////////////////////////////////////////////////////////////
// ERROR PAGE (Unified with same 5-sec rule as error modal)
//////////////////////////////////////////////////////////////
function outputErrorPage($msg) {
    echo '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Access Restricted</title>

<style>
    :root {
        --primary: #1a73e8;       /* Google Blue */
        --danger: #d93025;
        --text-dark: #202124;
        --text-light: #5f6368;
        --bg: #f8f9fa;
    }

    body {
        font-family: "Roboto", "Segoe UI", sans-serif;
        background: var(--bg);
        margin: 0;
        height: 100vh;
        display: flex;
        justify-content: center;
        align-items: center;
        color: var(--text-dark);
    }

    .card {
        background: #fff;
        width: 92%;
        max-width: 430px;
        padding: 40px 35px;
        border-radius: 12px;
        box-shadow: 0 6px 20px rgba(0,0,0,0.08);
        animation: fadeIn .6s ease-out;
        text-align: center;
    }

    .icon {
        font-size: 56px;
        color: var(--danger);
        margin-bottom: 10px;
    }

    h2 {
        font-size: 26px;
        font-weight: 600;
        margin-bottom: 10px;
    }

    p {
        font-size: 16px;
        color: var(--text-light);
        line-height: 1.6;
    }

    .countdown {
        margin-top: 15px;
        font-size: 18px;
        font-weight: 500;
        color: var(--primary);
    }

    .button {
        display: inline-block;
        margin-top: 28px;
        padding: 12px 28px;
        background: var(--primary);
        color: #fff;
        border-radius: 8px;
        font-size: 15px;
        font-weight: 500;
        text-decoration: none;
        transition: background .25s;
    }

    .button:hover {
        background: #1669c1;
    }

    @keyframes fadeIn {
        from { opacity: 0; transform: translateY(15px); }
        to   { opacity: 1; transform: translateY(0); }
    }
</style>
</head>

<body>

<div class="card">
    <div class="icon">⚠️</div>
    <h2>Access Restricted</h2>

    <p><?php echo htmlspecialchars($msg); ?></p>

    <p class="sub">You will be securely redirected…</p>

    <div class="countdown">
        Redirecting in <span id="count">5</span> seconds
    </div>

    <a href="awarcrown://open" class="button">Open App</a>
</div>

<script>
let c = 5;
const timer = setInterval(() => {
    document.getElementById("count").innerText = --c;
    if (c <= 0) clearInterval(timer);
}, 1000);

setTimeout(() => {
    window.location = "awarcrown://open";

    setTimeout(() => {
        window.location = "https://awarcrown.com";
    }, 5000);

}, 5000);
</script>

</body>
</html>
';
    exit;
}


//////////////////////////////////////////////////////////////
// Unauthorized Shortcut
//////////////////////////////////////////////////////////////
function outputUnauthorized() {
    outputErrorPage('Unauthorized access. Opening Awarcrown App…');
}


//////////////////////////////////////////////////////////////
// Reset Password Form
//////////////////////////////////////////////////////////////
function outputResetForm($token) {
    echo '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Reset Password</title>

<style>
    :root {
        --primary: #1a73e8;       /* Google Blue */
        --text-dark: #202124;
        --text-light: #5f6368;
        --bg: #f8f9fa;
        --border: #dadce0;
    }

    body {
        background: var(--bg);
        margin: 0;
        font-family: "Roboto", "Segoe UI", sans-serif;
        display: flex;
        justify-content: center;
        padding: 40px 20px;
    }

    .container {
        background: #fff;
        width: 100%;
        max-width: 420px;
        padding: 35px 30px;
        border-radius: 12px;
        box-shadow: 0 6px 18px rgba(0,0,0,0.08);
        animation: fadeIn .4s ease-out;
    }

    h2 {
        margin: 0;
        text-align: center;
        color: var(--text-dark);
        font-size: 26px;
        font-weight: 500;
        margin-bottom: 20px;
    }

    input {
        width: 100%;
        padding: 14px;
        margin: 12px 0;
        border: 1px solid var(--border);
        border-radius: 8px;
        font-size: 16px;
        outline: none;
        transition: border-color .25s;
    }

    input:focus {
        border-color: var(--primary);
        box-shadow: 0 0 0 3px rgba(26,115,232,0.15);
    }

    button {
        width: 100%;
        padding: 14px;
        background: var(--primary);
        color: #fff;
        font-size: 16px;
        font-weight: 500;
        border: none;
        border-radius: 8px;
        cursor: pointer;
        transition: background .25s;
        margin-top: 5px;
    }

    button:hover {
        background: #1669c1;
    }

    @keyframes fadeIn {
        from { opacity: 0; transform: translateY(15px); }
        to   { opacity: 1; transform: translateY(0); }
    }
</style>
</head>

<body>

<div class="container">
    <h2>Reset Password</h2>

    <form method="POST" action="?action=update-password">
        <input type="hidden" name="token" value="<?php echo htmlspecialchars($token); ?>">

        <input type="password" name="new_password"
               placeholder="New Password" required minlength="6">

        <input type="password" name="confirm_password"
               placeholder="Confirm Password" required minlength="6">

        <button type="submit">Reset Password</button>
    </form>
</div>

</body>
</html>
';
    exit;
}


//////////////////////////////////////////////////////////////
// MAIN ROUTER
//////////////////////////////////////////////////////////////
try {
    $action = $_GET['action'] ?? '';

    // Preflight
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit(0);

    // No action → unauthorized GET
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && empty($action)) {
        outputUnauthorized();
    }

    // -------- GET HANDLERS ----------
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        switch ($action) {

            case 'verify':
                handleVerify($pdo, $_GET);
                break;

            case 'reset':
                $token = $_GET['token'] ?? '';
                if (!$token) outputErrorPage('Reset link is missing.');

                $stmt = $pdo->prepare("SELECT user_id FROM email_verifications WHERE token=? AND expires_at>NOW()");
                $stmt->execute([$token]);

                if (!$stmt->fetch()) {
                    outputErrorPage('Invalid or expired reset link.');
                }

                outputResetForm($token);
                break;

            default:
                outputUnauthorized();
        }
    }

    // -------- POST HANDLERS ----------
    elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {

        $raw = file_get_contents('php://input');
        $data = json_decode($raw, true) ?: $_POST;

        switch ($action) {
            case 'register':
                handleRegister($pdo, $mail, $data, $jwtSecret);
                break;

            case 'login':
                handleLogin($pdo, $data, $jwtSecret);
                break;

            case 'refresh':
                handleRefresh($pdo, $data, $jwtSecret);
                break;

            case 'update-password':
                handleUpdatePassword($pdo, $data);
                break;

            case 'forgot-password':
                handleForgotPassword($pdo, $mail, $data);
                break;

            default:
                throw new Exception('Invalid action');
        }
    }

    // -------- Other Methods ----------
    else {
        throw new Exception('Method not allowed');
    }

} catch (Exception $e) {
    logError("Main error: " . $e->getMessage());

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        outputErrorPage($e->getMessage());
    } else {
        sendErrorResponse(400, $e->getMessage());
    }
}
//////////////////////////////////////////////////////////////
// HANDLER: REGISTER
//////////////////////////////////////////////////////////////
function handleRegister($pdo, $mail, $data, $jwtSecret) {
    try {
        $username = trim($data['username'] ?? '');
        $email    = trim($data['email'] ?? '');
        $password = $data['password'] ?? '';

        if (!$username || !$email || !$password) throw new Exception('All fields required');
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) throw new Exception('Invalid email');
        if (strlen($password) < 6) throw new Exception('Password too short');

        // Check existing user
        $stmt = $pdo->prepare("SELECT id FROM users WHERE username=? OR email=?");
        $stmt->execute([$username, $email]);
        if ($stmt->fetch()) throw new Exception('Username or email already taken');

        // Insert user
        $hash = password_hash($password, PASSWORD_DEFAULT);
        $pdo->prepare("INSERT INTO users (username, email, password_hash, is_active)
                       VALUES (?, ?, ?, 0)")
            ->execute([$username, $email, $hash]);

        $userId = $pdo->lastInsertId();

        // Create email verification token
        $token = hash('sha256', random_bytes(32));
        $pdo->prepare("INSERT INTO email_verifications (user_id, token, expires_at)
                       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 24 HOUR))")
            ->execute([$userId, $token]);

        // Send mail
        $mail->clearAddresses();
        $mail->addAddress($email);
        $mail->Subject = 'Verify Your Awarcrown Account';
        $mail->Body =
            "Hi $username,\n\nVerify your email:\n" .
            "https://server.awarcrown.com/auth/api?action=verify&token=$token\n\n" .
            "This link expires in 24 hours.";

        $mail->send();

        // JWT tokens
        $accessToken  = generateAccessToken($userId, $jwtSecret);
        $refreshToken = bin2hex(random_bytes(32));

        $pdo->prepare("INSERT INTO refresh_tokens (user_id, token, expires_at)
                       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))")
            ->execute([$userId, $refreshToken]);

        echo json_encode([
            'success' => true,
            'message' => 'Registered successfully. Verify using the link sent to your email.',
            'access_token'  => $accessToken,
            'refresh_token' => $refreshToken
        ]);
    } catch (Exception $e) {
        logError("Register error: " . $e->getMessage());
        sendErrorResponse(400, $e->getMessage());
    }
}


//////////////////////////////////////////////////////////////
// HANDLER: LOGIN
//////////////////////////////////////////////////////////////
function handleLogin($pdo, $data, $jwtSecret) {
    try {
        $identifier = trim($data['username'] ?? '');
        $password   = $data['password'] ?? '';

        if (!$identifier || !$password) throw new Exception('Credentials required');

        $stmt = $pdo->prepare("SELECT * FROM users WHERE username=? OR email=?");
        $stmt->execute([$identifier, $identifier]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user || !password_verify($password, $user['password_hash'])) {
            throw new Exception('Invalid credentials');
        }
        if (!$user['is_active']) {
            throw new Exception('Please verify your email before logging in.');
        }

        // NEW TOKENS
        $accessToken  = generateAccessToken($user['id'], $jwtSecret);

        $pdo->prepare("DELETE FROM refresh_tokens WHERE user_id=?")
            ->execute([$user['id']]);

        $refreshToken = bin2hex(random_bytes(32));

        $pdo->prepare("INSERT INTO refresh_tokens (user_id, token, expires_at)
                       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))")
            ->execute([$user['id'], $refreshToken]);

        echo json_encode([
            'success' => true,
            'user' => [
                'id'       => $user['id'],
                'username' => $user['username']
            ],
            'access_token'  => $accessToken,
            'refresh_token' => $refreshToken
        ]);
    } catch (Exception $e) {
        logError("Login error: " . $e->getMessage());
        sendErrorResponse(401, $e->getMessage());
    }
}


//////////////////////////////////////////////////////////////
// HANDLER: REFRESH TOKEN
//////////////////////////////////////////////////////////////
function handleRefresh($pdo, $data, $jwtSecret) {
    try {
        $refresh = trim($data['refresh_token'] ?? '');
        if (!$refresh) throw new Exception('Refresh token required');

        $stmt = $pdo->prepare("SELECT user_id FROM refresh_tokens
                               WHERE token=? AND expires_at > NOW()");
        $stmt->execute([$refresh]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$row) throw new Exception('Invalid refresh token');

        $userId = $row['user_id'];

        // Generate new tokens
        $newAccess  = generateAccessToken($userId, $jwtSecret);
        $newRefresh = bin2hex(random_bytes(32));

        $pdo->prepare("DELETE FROM refresh_tokens WHERE user_id=?")
            ->execute([$userId]);
        $pdo->prepare("INSERT INTO refresh_tokens (user_id, token, expires_at)
                       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))")
            ->execute([$userId, $newRefresh]);

        echo json_encode([
            'success'       => true,
            'access_token'  => $newAccess,
            'refresh_token' => $newRefresh
        ]);
    } catch (Exception $e) {
        sendErrorResponse(401, $e->getMessage());
    }
}


//////////////////////////////////////////////////////////////
// HANDLER: EMAIL VERIFICATION
//////////////////////////////////////////////////////////////
function handleVerify($pdo, $data) {
    try {
        $token = $data['token'] ?? '';
        if (!$token) throw new Exception('Token missing');

        $stmt = $pdo->prepare(
            "SELECT user_id FROM email_verifications WHERE token=? AND expires_at > NOW()"
        );
        $stmt->execute([$token]);
        $row = $stmt->fetch();

        if (!$row) {
            throw new Exception('Invalid or expired verification link');
        }

        $pdo->prepare("UPDATE users SET is_active=1 WHERE id=?")
            ->execute([$row['user_id']]);

        $pdo->prepare("DELETE FROM email_verifications WHERE token=?")
            ->execute([$token]);

        // SUCCESS REDIRECT (awarcrown://verified)
        outputSuccessModal('Your email has been verified successfully!');
    }
    catch (Exception $e) {
        outputErrorPage('Verification failed: ' . $e->getMessage());
    }
}


//////////////////////////////////////////////////////////////
// HANDLER: FORGOT PASSWORD
//////////////////////////////////////////////////////////////
function handleForgotPassword($pdo, $mail, $data) {
    try {
        $email = trim($data['email'] ?? '');
        if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new Exception('Valid email required');
        }

        // Fix bad fetch logic
        $stmt = $pdo->prepare("SELECT id, username FROM users WHERE email=?");
        $stmt->execute([$email]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        // Always send success for security — do not reveal account existence
        if ($user) {
            $token = hash('sha256', random_bytes(32));

            $pdo->prepare("DELETE FROM email_verifications WHERE user_id=?")
                ->execute([$user['id']]);

            $pdo->prepare("INSERT INTO email_verifications (user_id, token, expires_at)
                           VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 1 HOUR))")
                ->execute([$user['id'], $token]);

            // send email
            $mail->clearAddresses();
            $mail->addAddress($email);
            $mail->Subject = 'Password Reset - Awarcrown';
            $mail->Body =
                "Reset your password:\n" .
                "https://server.awarcrown.com/auth/api?action=reset&token=$token\n\n" .
                "Expires in 1 hour.";
            $mail->send();
        }

        echo json_encode([
            'success' => true,
            'message' => 'If this email is registered, a reset link has been sent. Estimated delivery: 1m 30s.'
        ]);

    } catch (Exception $e) {
        sendErrorResponse(400, $e->getMessage());
    }
}


//////////////////////////////////////////////////////////////
// HANDLER: UPDATE PASSWORD AFTER RESET
//////////////////////////////////////////////////////////////
function handleUpdatePassword($pdo, $data) {
    try {
        $token   = trim($data['token'] ?? '');
        $new     = $data['new_password'] ?? '';
        $confirm = $data['confirm_password'] ?? '';

        if (!$token || !$new || !$confirm) throw new Exception('All fields required');
        if ($new !== $confirm) throw new Exception('Passwords do not match');
        if (strlen($new) < 6) throw new Exception('Password too short');

        $stmt = $pdo->prepare(
            "SELECT user_id FROM email_verifications WHERE token=? AND expires_at > NOW()"
        );
        $stmt->execute([$token]);
        $row = $stmt->fetch();

        if (!$row) throw new Exception('Invalid reset link');

        // Update password
        $pdo->prepare("UPDATE users SET password_hash=? WHERE id=?")
            ->execute([password_hash($new, PASSWORD_DEFAULT), $row['user_id']]);

        // Invalidate refresh tokens
        $pdo->prepare("DELETE FROM refresh_tokens WHERE user_id=?")
            ->execute([$row['user_id']]);

        // Remove verification token
        $pdo->prepare("DELETE FROM email_verifications WHERE token=?")
            ->execute([$token]);

        // Success → awarcrown://verified
        outputSuccessModal('Password updated successfully!');

    } catch (Exception $e) {
        outputErrorPage('Password reset failed: ' . $e->getMessage());
    }
}
?>

