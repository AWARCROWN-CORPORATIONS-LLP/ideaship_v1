<?php
header('Content-Type: application/json');
require_once 'config.php';

// === Define constants ===
define('UPLOAD_DIR', __DIR__ . '/uploads/'); // Physical folder for uploads
define('BASE_URL', 'https://server.awarcrown.com/accessprofile/uploads/'); // Public URL prefix

// Allow CORS
header('Access-Control-Allow-Origin: *');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
    exit;
}

// === Runtime upload limits ===
ini_set('upload_max_filesize', '10M');
ini_set('post_max_size', '12M');
ini_set('max_file_uploads', '20');
ini_set('memory_limit', '256M');

// === Utility: sanitize input ===
function sanitize($data) {
    return trim($data);
}

// === Centralized Error Logger ===
function logError($message, $context = [], $isCritical = false) {
    $logMessage = sprintf(
        "[%s] %s | Context: %s%s",
        date('Y-m-d H:i:s'),
        $message,
        json_encode($context, JSON_UNESCAPED_SLASHES),
        PHP_EOL
    );
    error_log($logMessage);

    // Optional: write to separate error_log.txt
    $customLog = __DIR__ . '/error_log.txt';
    file_put_contents($customLog, $logMessage, FILE_APPEND);
}

// === Structured response helper ===
function respond($success, $message, $data = [], $code = 200) {
    http_response_code($code);
    echo json_encode(array_merge([
        'success' => $success,
        'message' => $message,
    ], $data), JSON_UNESCAPED_SLASHES);
    exit;
}

// === File upload error mapping ===
function getUploadErrorMessage($code) {
    return match ($code) {
        UPLOAD_ERR_INI_SIZE   => 'File exceeds server limit (upload_max_filesize)',
        UPLOAD_ERR_FORM_SIZE  => 'File exceeds form limit (MAX_FILE_SIZE)',
        UPLOAD_ERR_PARTIAL    => 'File partially uploaded',
        UPLOAD_ERR_NO_FILE    => 'No file uploaded',
        UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder on server',
        UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk',
        UPLOAD_ERR_EXTENSION  => 'File upload stopped by PHP extension',
        default               => 'Unknown upload error',
    };
}

try {
    // === Check username ===
    if (empty($_POST['username'])) {
        logError("Missing username", ['POST' => $_POST]);
        respond(false, 'Username is required', [], 400);
    }

    $username = sanitize($_POST['username']);

    // === Validate user ===
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = :username AND is_active = 1");
    $stmt->execute([':username' => $username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        logError("User not found or inactive", ['username' => $username]);
        respond(false, 'User not found or inactive', [], 404);
    }

    $user_id = $user['id'];

    // === Validate file upload ===
    if (!isset($_FILES['profile_picture'])) {
        logError("No file field received", ['FILES' => $_FILES]);
        respond(false, 'No file received', [], 400);
    }

    $file = $_FILES['profile_picture'];

    if ($file['error'] !== UPLOAD_ERR_OK) {
        $errorMsg = getUploadErrorMessage($file['error']);
        logError("File upload error", ['error_code' => $file['error'], 'error_message' => $errorMsg]);
        respond(false, "Upload failed: $errorMsg", [], 400);
    }

    // === Check file type and size ===
    $allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'image/jpg'];
    $max_size = 5 * 1024 * 1024; // 5MB

    if (!in_array($file['type'], $allowed_types, true)) {
        logError("Invalid file type", ['type' => $file['type']]);
        respond(false, 'Invalid file type. Only JPG, PNG, GIF allowed', [], 400);
    }

    if ($file['size'] > $max_size) {
        logError("File too large", ['size' => $file['size'], 'max_allowed' => $max_size]);
        respond(false, 'File too large (max 5MB)', [], 400);
    }

    // === Generate unique filename and destination ===
    $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $filename = 'profile_' . $user_id . '_' . time() . '.' . $extension;
    $destination = rtrim(UPLOAD_DIR, '/') . '/' . $filename;

    // Ensure upload directory exists
    if (!is_dir(UPLOAD_DIR) && !mkdir(UPLOAD_DIR, 0775, true)) {
        logError("Failed to create upload directory", ['path' => UPLOAD_DIR]);
        respond(false, 'Server upload directory not writable', [], 500);
    }

    // === Move uploaded file ===
    if (!move_uploaded_file($file['tmp_name'], $destination)) {
        logError("move_uploaded_file() failed", ['tmp' => $file['tmp_name'], 'dest' => $destination]);
        respond(false, 'Failed to move uploaded file', [], 500);
    }

    // === Update DB with filename only ===
    $stmt = $pdo->prepare("UPDATE users SET profile_picture = :filename WHERE id = :uid");
    $stmt->execute([':filename' => $filename, ':uid' => $user_id]);

    // === Response with full public URL ===
    $responseData = [
        'profile_picture' => BASE_URL . $filename,
        'size' => $file['size'],
        'type' => $file['type']
    ];

    logError("Profile picture updated successfully", ['user_id' => $user_id, 'file' => $filename]);
    respond(true, 'Profile picture updated successfully', $responseData, 200);

} catch (Throwable $e) {
    logError("Exception caught", [
        'message' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine(),
        'trace' => $e->getTraceAsString(),
        'POST' => $_POST,
        'FILES' => $_FILES ?? []
    ], true);

    respond(false, 'Internal server error. Please try again later.', [], 500);
}
?>
