<?php
header('Content-Type: application/json; charset=UTF-8');
mb_internal_encoding("UTF-8");

// Enable logging
ini_set('log_errors', 1);
ini_set('error_log', 'errors.log');
ini_set('display_errors', 1); // Disable this in production
ob_start();

define("INCLUDE_FLAG", true);
require 'config.php';

// Force database to support emojis
$pdo->exec("SET NAMES utf8mb4");

// Encryption settings
define("ENCRYPTION_KEY", base64_decode("7/bUxXBcXrgqyASvQSbLSKNce+rvWJt0botpIrA4poQ="));
define("ENCRYPTION_METHOD", "AES-256-CBC");

function encryptData($data) {
    $iv = openssl_random_pseudo_bytes(openssl_cipher_iv_length(ENCRYPTION_METHOD));
    $encryptedData = openssl_encrypt($data, ENCRYPTION_METHOD, ENCRYPTION_KEY, 0, $iv);
    return base64_encode($encryptedData . "::" . $iv);
}

function decryptData($data) {
    if (!$data) return null;
    $decodedData = base64_decode($data);
    if (strpos($decodedData, "::") === false) return null;
    list($encryptedData, $iv) = explode("::", $decodedData, 2);
    return openssl_decrypt($encryptedData, ENCRYPTION_METHOD, ENCRYPTION_KEY, 0, $iv);
}

// Get POST data
$username = $_POST['username'] ?? '';
$email    = $_POST['email'] ?? '';

if ($username === '' || $email === '') {
    echo json_encode(['status' => 'error', 'message' => 'Username and email required.']);
    exit;
}

try {
    // Validate user
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = :username AND email = :email");
    $stmt->execute(['username' => $username, 'email' => $email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) throw new Exception("User not found.");
    $user_id = $user['id'];

    if ($_SERVER["REQUEST_METHOD"] !== "POST") {
        throw new Exception("Invalid request method. Use POST.");
    }

    // Validate post content (UTF-8 safe)
    $content = trim($_POST['content'] ?? '');
    if ($content === '') throw new Exception("Post content cannot be empty.");

    if (mb_strlen($content, 'UTF-8') > 65535) {
        throw new Exception("Post content is too long.");
    }

    // Visibility
    $visibility = $_POST['visibility'] ?? 'public';
    if (!in_array($visibility, ['public', 'friends', 'private'])) {
        $visibility = 'public';
    }

    // Image upload
    $media_url = null;

    if (!empty($_FILES['image']['name']) && $_FILES['image']['error'] !== UPLOAD_ERR_NO_FILE) {

        switch ($_FILES['image']['error']) {
            case UPLOAD_ERR_INI_SIZE:
            case UPLOAD_ERR_FORM_SIZE:
                throw new Exception("File size exceeds limit.");
            case UPLOAD_ERR_PARTIAL:
                throw new Exception("File upload interrupted.");
            case UPLOAD_ERR_NO_TMP_DIR:
                throw new Exception("Temporary folder missing.");
            case UPLOAD_ERR_CANT_WRITE:
                throw new Exception("Failed to write file to disk.");
            case UPLOAD_ERR_EXTENSION:
                throw new Exception("File upload stopped by extension.");
        }

        $max_file_size = 5 * 1024 * 1024;
        if ($_FILES['image']['size'] > $max_file_size) {
            throw new Exception("File size exceeds 5MB limit.");
        }

        $allowed_types = ['image/jpeg', 'image/png', 'image/gif'];
        $file_type = mime_content_type($_FILES['image']['tmp_name']);
        if (!in_array($file_type, $allowed_types)) {
            throw new Exception("Invalid file type. Only JPEG, PNG, GIF allowed.");
        }

        $targetDir = "Posts/";
        if (!is_dir($targetDir) && !mkdir($targetDir, 0755, true)) {
            throw new Exception("Failed to create upload directory.");
        }

        $file_name = uniqid() . "_" . basename($_FILES['image']['name']);
        $media_path = $targetDir . $file_name;

        if (!move_uploaded_file($_FILES['image']['tmp_name'], $media_path)) {
            throw new Exception("Failed to upload image.");
        }

        $media_url = encryptData($media_path);
    }

    // Insert post
    $stmt = $pdo->prepare("
        INSERT INTO posts (user_id, content, media_url, visibility, created_at, updated_at)
        VALUES (:user_id, :content, :media_url, :visibility, NOW(), NOW())
    ");

    $stmt->execute([
        'user_id'   => $user_id,
        'content'   => $content,
        'media_url' => $media_url,
        'visibility'=> $visibility
    ]);

    echo json_encode(['status' => 'success', 'message' => 'Post uploaded successfully.']);

} catch (Exception $e) {
    error_log("Error: " . $e->getMessage() . " @ line " . $e->getLine());
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}

ob_end_flush();
?>
