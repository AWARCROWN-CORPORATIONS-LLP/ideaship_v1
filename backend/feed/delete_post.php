<?php
session_start();
define('INCLUDE_FLAG', true);
require 'config.php'; // provides $pdo

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// --------------------------------------------------
// AES Decryption
// --------------------------------------------------
define("ENCRYPTION_KEY", base64_decode("7/bUxXBcXrgqyASvQSbLSKNce+rvWJt0botpIrA4poQ="));
define("ENCRYPTION_METHOD", "AES-256-CBC");

function decryptData($data)
{
    if (!$data) return null;

    $decoded = base64_decode($data);
    if ($decoded === false || strpos($decoded, "::") === false) {
        error_log("❌ Invalid encrypted format");
        return null;
    }

    list($encrypted, $iv) = explode("::", $decoded, 2);
    return openssl_decrypt($encrypted, ENCRYPTION_METHOD, ENCRYPTION_KEY, 0, $iv);
}

// --------------------------------------------------
// Validate Input
// --------------------------------------------------
if (!isset($_POST['post_id'])) {
    echo json_encode(["status" => "error", "message" => "post_id is required"]);
    exit;
}

$post_id = intval($_POST['post_id']);

try {
    // Fetch media URL
    $stmt = $pdo->prepare("SELECT media_url FROM posts WHERE post_id = ?");
    $stmt->execute([$post_id]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        echo json_encode(["status" => "error", "message" => "Post not found"]);
        exit;
    }

    $encrypted_media = $row['media_url'];
    $file_path = null;

    // --------------------------------------------------
    // Try to decrypt only if there is media
    // --------------------------------------------------
    if (!empty($encrypted_media)) {
        $file_path = decryptData($encrypted_media);
        error_log("📂 Decrypted media path: " . $file_path);
    }

    // --------------------------------------------------
    // Delete media file ONLY IF it exists
    // --------------------------------------------------
    if ($file_path && file_exists($file_path)) {
        if (!is_dir($file_path)) {
            unlink($file_path);
        }
    }

    // --------------------------------------------------
    // Always delete the post record
    // --------------------------------------------------
    $deleteStmt = $pdo->prepare("DELETE FROM posts WHERE post_id = ?");
    $deleteStmt->execute([$post_id]);

    echo json_encode([
        "status" => "success",
        "message" => "Post deleted successfully"
    ]);

} catch (PDOException $e) {
    error_log("🔥 DB Error: " . $e->getMessage());
    echo json_encode(["status" => "error", "message" => "Database error occurred"]);
}
?>
