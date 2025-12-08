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
// This file is assumed to define $pdo (PDO connection) and $jwtSecret
// and potentially other configurations.
require_once 'config.php'; 

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

// === PHPMailer Setup Class/Helper (Improved: use a class or helper to avoid code duplication) ===

/**
 * Creates and configures a PHPMailer instance for standard use.
 * @param bool $isHTML Set to true for HTML emails, false for plain text.
 * @return PHPMailer Configured PHPMailer object.
 */
function createMailer($isHTML = false) {
    $mail = new PHPMailer(true);
    try {
        // Configuration should ideally come from config.php or environment
        $mail->isSMTP();
        $mail->Host = 'localhost';
        $mail->Port = 25;
        $mail->SMTPAuth = false;
        $mail->SMTPSecure = false;
        $mail->Timeout = 15;
        $mail->CharSet = 'UTF-8';
        // Note: base64 encoding is not typical for plain text or simple HTML. 
        // Default encoding is usually better unless specific requirements exist.
        $mail->Encoding = 'quoted-printable'; 
        
        $mail->isHTML($isHTML);
        $mail->setFrom('support@awarcrown.com', 'Awarcrown Auth');
        $mail->addReplyTo('support@awarcrown.com', 'Awarcrown Support');
        return $mail;
    } catch (Exception $e) {
        error_log("PHPMailer setup failed: " . $e->getMessage());
        // In a real application, you might throw the exception here 
        // or return null and check in the calling function.
        throw new Exception("Mailer configuration error.");
    }
}

// Global $mail setup is REMOVED to prevent reuse/leakage. 
// Handlers will call createMailer() or receive $mail if it's reused carefully.


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
    // SECURITY IMPROVEMENT: Sanitize input before writing to log to prevent log injection
    $msg = filter_var($msg, FILTER_SANITIZE_STRING); 
    error_log(date('[Y-m-d H:i:s] ') . $msg . "\n", 3, __DIR__ . '/error.log');
}
function sendErrorResponse($status, $msg) {
    http_response_code($status);
    // Ensure all output is JSON for API calls
    header('Content-Type: application/json'); 
    echo json_encode(['success' => false, 'message' => $msg]);
    exit;
}


// === HTML Output Functions (No changes needed, they seem fine for outputting the modals/pages) ===

function outputSuccessModal($msg) {
    // ... (HTML/JS content is unchanged)
    echo '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Success</title>

<style>
    :root {
        --primary: #1a73e8;        /* Google Blue */
        --success: #0f9d58;        /* Google Green */
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
        to  { opacity: 1; transform: translateY(0); }
    }
</style>
</head>

<body>

<div class="card">
    <div class="icon">✔️</div>

    <h2>Email verification Success</h2>

    <p><?php echo htmlspecialchars($msg); ?></p>
    <p class="sub">Opening Awarcrown App…</p>

    <div class="countdown">
        Redirecting in <span id="count">5</span> seconds
    </div>

    <a href="awarcrown://open" class="button">Open App Now</a>
</div>

<script>
let c = 5;
const timer = setInterval(() => {
    document.getElementById("count").innerText = --c;
    if (c <= 0) clearInterval(timer);
}, 1000);

setTimeout(() => {
    window.location = "awarcrown://open";

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


function outputErrorModal($msg) {
    // ... (HTML/JS content is unchanged)
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

function outputErrorPage($msg) {
    // ... (HTML/JS content is unchanged)
    echo '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Access Restricted</title>

<style>
    :root {
        --primary: #1a73e8;        /* Google Blue */
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
        to  { opacity: 1; transform: translateY(0); }
    }
</style>
</head>

<body>

<div class="card">
    <div class="icon">Awarcrown</div>
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


function outputUnauthorized() {
    outputErrorPage('Unauthorized access. Opening Awarcrown App…');
}


function outputResetForm($token) {
    // ... (HTML content is unchanged)
    echo '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Reset Password</title>

<style>
    :root {
        --primary: #1a73e8;        /* Google Blue */
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
        to  { opacity: 1; transform: translateY(0); }
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


// === Main Execution Block (Corrected for PDO and JWT Secret dependency) ===

// NOTE: We assume $pdo and $jwtSecret are defined in config.php
// If not, you must define them here before the try block.
// Example:
// $pdo = new PDO('mysql:host=...;dbname=...', 'user', 'pass');
// $jwtSecret = 'YOUR_SECURE_SECRET';

try {
    $action = $_GET['action'] ?? '';

    // Preflight
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        // Set Content-Length to 0 for a valid preflight response
        header('Content-Length: 0');
        exit(0);
    }

    // No action → unauthorized GET
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && empty($action)) {
        outputUnauthorized();
    }

    // -------- GET HANDLERS ----------
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        switch ($action) {

            case 'verify':
                // Pass $pdo to the handler
                handleVerify($pdo, $_GET); 
                break;

            case 'reset':
                $token = $_GET['token'] ?? '';
                if (!$token) outputErrorPage('Reset link is missing.');

                $stmt = $pdo->prepare("SELECT user_id FROM email_verifications WHERE token=? AND expires_at>NOW()");
                $stmt->execute([$token]);

                // Check for valid, non-expired token.
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

        // Set Content-Type for JSON API responses
        header('Content-Type: application/json');

        $raw = file_get_contents('php://input');
        // Prefer JSON decode for API. Fallback to $_POST for form data.
        $data = json_decode($raw, true) ?: $_POST; 

        switch ($action) {
            case 'register':
                // Pass $pdo and $jwtSecret to the handler.
                handleRegister($pdo, $data, $jwtSecret); 
                break;

            case 'login':
                // Pass $pdo and $jwtSecret to the handler.
                handleLogin($pdo, $data, $jwtSecret); 
                break;

            case 'refresh':
                // Pass $pdo and $jwtSecret to the handler.
                handleRefresh($pdo, $data, $jwtSecret); 
                break;

            case 'update-password':
                // Pass $pdo to the handler.
                handleUpdatePassword($pdo, $data); 
                break;

            case 'forgot-password':
                // Pass $pdo to the handler.
                handleForgotPassword($pdo, $data); 
                break;

            default:
                // Correct status code for API call with invalid action
                sendErrorResponse(400, 'Invalid action'); 
        }
    }

    // -------- Other Methods ----------
    else {
        // Correct status code for Method Not Allowed
        sendErrorResponse(405, 'Method not allowed'); 
    }

} catch (Exception $e) {
    logError("Main error: " . $e->getMessage());

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        outputErrorPage($e->getMessage());
    } else {
        // Use 500 for unhandled exceptions in API calls
        sendErrorResponse(500, 'An unexpected error occurred: ' . $e->getMessage()); 
    }
}

// === HANDLER FUNCTIONS (Corrected for dependency injection) ===

function handleRegister($pdo, $data, $jwtSecret) {
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

        // Start Transaction for safety
        $pdo->beginTransaction(); 

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

        // --- Send mail (use the helper function) ---
        $mail = createMailer(false); // Plain text for verification link
        $mail->addAddress($email);
        $mail->Subject = 'Verify Your Awarcrown Account';
        $mail->Body =
            "Hi $username,\n\nVerify your email:\n" .
            "https://server.awarcrown.com/auth/api?action=verify&token=$token\n\n" .
            "This link expires in 24 hours.";

        $mail->send();
        // --- End mail send ---

        // JWT tokens
        $accessToken  = generateAccessToken($userId, $jwtSecret);
        $refreshToken = bin2hex(random_bytes(32));

        $pdo->prepare("INSERT INTO refresh_tokens (user_id, token, expires_at)
                       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))")
            ->execute([$userId, $refreshToken]);

        $pdo->commit(); // Commit transaction on success

        echo json_encode([
            'success' => true,
            'message' => 'Registered successfully. Verify using the link sent to your email.',
            'access_token'  => $accessToken,
            'refresh_token' => $refreshToken
        ]);
    } catch (Exception $e) {
        if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack(); // Rollback on error
        logError("Register error: " . $e->getMessage());
        sendErrorResponse(400, $e->getMessage());
    }
}


//////////////////////////////////////////////////////////////
// HANDLER: LOGIN
//////////////////////////////////////////////////////////////
function sanitizeInput($value) {
    // SECURITY IMPROVEMENT: FILTER_SANITIZE_STRING is deprecated. Use more specific filters or htmlspecialchars.
    // For an identifier, a simple trim is often enough, the validation handles the rest.
    return trim($value); 
}

function handleLogin($pdo, $data, $jwtSecret) {
    try {
        // --- 1. Input sanitization ---
        $identifier = sanitizeInput($data['username'] ?? '');
        $password   = $data['password'] ?? '';
        $password   = trim($password);

        if (empty($identifier) || empty($password)) {
            throw new Exception('Username or password required.');
        }

        // --- 2. Validate identifier format and determine query ---
        // Validate against both email and username formats if possible
        $isEmail = filter_var($identifier, FILTER_VALIDATE_EMAIL);
        $query = "SELECT * FROM users WHERE ";
        $params = [];

        if ($isEmail) {
            $query .= "email = ?";
            $params = [$identifier];
        } elseif (preg_match('/^[a-zA-Z0-9_]{3,30}$/', $identifier)) {
            $query .= "username = ?";
            $params = [$identifier];
        } else {
            throw new Exception('Invalid username or email format.');
        }

        // --- 3. Safe SQL execution (Prepared Statements) ---
        $stmt = $pdo->prepare($query);
        $stmt->execute($params);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user) {
            // SECURITY: Use a generic error message
            throw new Exception('Invalid login credentials.'); 
        }

        // --- 4. Verify password securely ---
        if (!password_verify($password, $user['password_hash'])) {
            // SECURITY: Use a generic error message
            throw new Exception('Invalid login credentials.'); 
        }

        // --- 5. Check account status ---
        if (!$user['is_active']) {
            throw new Exception('Please verify your email before logging in.');
        }

        // --- 6. Generate Access Token ---
        $accessToken = generateAccessToken($user['id'], $jwtSecret);

        // --- 7. Refresh Token Rotation (with transaction) ---
        $pdo->beginTransaction(); 
        
        // Delete old tokens (Good practice: rotate and invalidate)
        $pdo->prepare("DELETE FROM refresh_tokens WHERE user_id = ?")->execute([$user['id']]); 

        $refreshToken = bin2hex(random_bytes(32));

        $pdo->prepare("
            INSERT INTO refresh_tokens (user_id, token, expires_at)
            VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))
        ")->execute([$user['id'], $refreshToken]);

        $pdo->commit(); // Commit transaction on success

        // --- 8. Clean user output (never send password_hash) ---
        $userResponse = [
            'id'       => (int)$user['id'],
            'username' => htmlspecialchars($user['username'], ENT_QUOTES, 'UTF-8'),
            'email'    => htmlspecialchars($user['email'], ENT_QUOTES, 'UTF-8'),
            'role'     => $user['role'] ?? 'user',
            'verified' => (bool)$user['is_active']
        ];

        echo json_encode([
            'success'        => true,
            'user'           => $userResponse,
            'access_token'   => $accessToken,
            'refresh_token'  => $refreshToken
        ]);

    } catch (Exception $e) {
        if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack(); // Rollback on error
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

        if (!$row) throw new Exception('Invalid or expired refresh token');

        $userId = $row['user_id'];

        // Start Transaction
        $pdo->beginTransaction(); 

        // Delete the *old* token (single-use/rotation model)
        $pdo->prepare("DELETE FROM refresh_tokens WHERE token=?")
             ->execute([$refresh]); 

        // Generate new tokens
        $newAccess  = generateAccessToken($userId, $jwtSecret);
        $newRefresh = bin2hex(random_bytes(32));

        // Insert new token
        $pdo->prepare("INSERT INTO refresh_tokens (user_id, token, expires_at)
                       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))")
            ->execute([$userId, $newRefresh]);

        $pdo->commit(); // Commit transaction

        echo json_encode([
            'success'       => true,
            'access_token'  => $newAccess,
            'refresh_token' => $newRefresh
        ]);
    } catch (Exception $e) {
        if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack(); // Rollback on error
        sendErrorResponse(401, $e->getMessage());
    }
}


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

        $pdo->beginTransaction();

        // Activate user
        $pdo->prepare("UPDATE users SET is_active=1 WHERE id=?")
            ->execute([$row['user_id']]);

        // Delete token
        $pdo->prepare("DELETE FROM email_verifications WHERE token=?")
            ->execute([$token]);

        $pdo->commit();

// ================
// SEND WELCOME MAIL (Corrected to use createMailer and not redefine PHPMailer setup)
// ================
        try {
            $stmt = $pdo->prepare("SELECT username, email FROM users WHERE id=?");
            $stmt->execute([$row['user_id']]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($user) {

                // --------------------------------
                // Build HTML template 
                // --------------------------------
                $htmlTemplate = '
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Welcome to Awarcrown Ideaship</title>

<style>
    body {
        font-family: Arial, Helvetica, sans-serif;
        background: #f4f6f9;
        margin: 0;
        padding: 0;
    }
    .container {
        background: #ffffff;
        max-width: 650px;
        margin: 30px auto;
        padding: 40px;
        border-radius: 12px;
        border: 1px solid #e5e8eb;
    }
    h2 {
        color: #1a202c;
        font-size: 26px;
        margin-top: 10px;
        font-weight: 600;
    }
    p {
        color: #4a5568;
        font-size: 16px;
        line-height: 1.6;
    }
    /* Removed .loader, it is not needed in a welcome email. */
    .footer {
        margin-top: 40px;
        text-align: center;
        font-size: 13px;
        color: #718096;
    }
</style>

</head>
<body>

<div class="container">
    <h2>Welcome to the Awarcrown Ideaship Family</h2>

    <p>Dear {{USERNAME}},</p>

    <p>
        Your email has been successfully verified, and your account is now active.
        We are excited to welcome you into the Awarcrown Ideaship family, a place where innovators,
        creators, and future leaders build meaningful impact together.
    </p>

    <p>
        You now have full access to our platform.
        We look forward to seeing your journey, your ideas, and the value you bring.
    </p>

    <p>
        If you require assistance, feel free to reply to this email.
        Our support team is here to help anytime.
    </p>

    <div class="footer">
        Awarcrown Corporations LLP<br>
        Building the Future, Idea by Idea
    </div>
</div>

</body>
</html>
';

                // Replace username placeholder
                $htmlTemplate = str_replace('{{USERNAME}}', htmlspecialchars($user['username']), $htmlTemplate);

                // --------------------------------
                // SEND EMAIL (using the helper)
                // --------------------------------
                $mail = createMailer(true); // HTML email
                $mail->addAddress($user['email']);
                $mail->Subject = "Welcome to Awarcrown Ideaship";
                $mail->Body = $htmlTemplate;

                $mail->send();
            }

        } catch (Exception $e) {
            // Log this as a soft failure; user verification is already successful
            error_log("Welcome email failed: " . $e->getMessage()); 
        }

        outputSuccessModal('Email verified successfully! You can now log in.');

    } catch (Exception $e) {
        if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack(); // Rollback on error
        logError("Verification error: " . $e->getMessage());
        outputErrorPage('Verification Failed: ' . $e->getMessage());
    }
}



function handleForgotPassword($pdo, $data) {
    try {
        $email = trim($data['email'] ?? '');
        if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            // SECURITY: Never throw here, proceed to generic success message
            // throw new Exception('Valid email required'); 
        }

        // Fix bad fetch logic
        $stmt = $pdo->prepare("SELECT id, username, email FROM users WHERE email=?");
        $stmt->execute([$email]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        // Always send success for security — do not reveal account existence
        if ($user) {
            $token = hash('sha256', random_bytes(32));

            $pdo->beginTransaction(); // Start Transaction

            // Clear old tokens for this user
            $pdo->prepare("DELETE FROM email_verifications WHERE user_id=?")
                ->execute([$user['id']]);

            // Insert new token
            $pdo->prepare("INSERT INTO email_verifications (user_id, token, expires_at)
                           VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 1 HOUR))")
                ->execute([$user['id'], $token]);

            $pdo->commit(); // Commit Transaction

            // send email
            $mail = createMailer(false); // Plain text for reset link
            $mail->addAddress($user['email']); // Use the fetched email
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
        if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack(); // Rollback on error
        // SECURITY: Log the error but still send generic success to the client
        logError("Forgot Password email failed: " . $e->getMessage()); 
        echo json_encode([
            'success' => true,
            'message' => 'If this email is registered, a reset link has been sent. Estimated delivery: 1m 30s.'
        ]);
    }
}



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

        if (!$row) throw new Exception('Invalid or expired reset link.');

        $pdo->beginTransaction(); // Start Transaction

        // Update password
        $pdo->prepare("UPDATE users SET password_hash=? WHERE id=?")
            ->execute([password_hash($new, PASSWORD_DEFAULT), $row['user_id']]);

        // Invalidate refresh tokens
        $pdo->prepare("DELETE FROM refresh_tokens WHERE user_id=?")
            ->execute([$row['user_id']]);

        // Remove verification token
        $pdo->prepare("DELETE FROM email_verifications WHERE token=?")
            ->execute([$token]);
            
        $pdo->commit(); // Commit Transaction

        
        outputSuccessModal('Password updated successfully! You can now log in.');

    } catch (Exception $e) {
        if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack(); // Rollback on error
        logError("Update Password error: " . $e->getMessage());
        outputErrorPage('Password reset failed: ' . $e->getMessage());
    }
}
?>