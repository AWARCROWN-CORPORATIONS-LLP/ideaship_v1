<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

error_reporting(E_ALL);
ini_set("log_errors", 1);
ini_set("error_log", __DIR__ . "/php_error.log");

require_once "config.php"; // PDO connection

// === Encryption Config ===
define("ENCRYPTION_KEY", base64_decode("7/bUxXBcXrgqyASvQSbLSKNce+rvWJt0botpIrA4poQ="));
define("ENCRYPTION_METHOD", "AES-256-CBC");

function decryptData($data) {
    if (!$data) return null;

    $decoded = base64_decode($data);
    if ($decoded === false || strpos($decoded, "::") === false) return null;

    list($encrypted, $iv) = explode("::", $decoded, 2);

    return openssl_decrypt(
        $encrypted,
        ENCRYPTION_METHOD,
        ENCRYPTION_KEY,
        0,
        $iv
    ) ?: null;
}

try {
    if (!isset($_GET['username'])) {
        error_log("Search Error: Missing username parameter.");
        echo json_encode(["error" => "Missing search query"]);
        exit;
    }

    $search = trim($_GET['username']);

    if ($search === "") {
        echo json_encode(["results" => []]);
        exit;
    }

    // Search query
    $sql = "
        SELECT 
            username,
            profile_picture
        FROM users
        WHERE username LIKE :search
        LIMIT 20
    ";

    $stmt = $pdo->prepare($sql);

    if (!$stmt) {
        error_log("SQL Prepare Error: " . json_encode($pdo->errorInfo()));
        echo json_encode(["error" => "Server error"]);
        exit;
    }

    $stmt->execute([
        ":search" => "%$search%"
    ]);

    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $results = [];

    foreach ($rows as $row) {

        // decrypt encrypted profile image
        $decryptedImage = decryptData($row["profile_picture"]);

        // format URL
        $profileImageURL = $decryptedImage
            ? "https://server.awarcrown.com/profile_images/" . $decryptedImage
            : "https://server.awarcrown.com/defaults/default_user.png";

        $results[] = [
            "username"         => $row["username"],
            "profile_picture"    => $profileImageURL
        ];
    }

    echo json_encode(["results" => $results]);

} catch (Exception $e) {
    error_log("Fatal Error: " . $e->getMessage());
    echo json_encode(["error" => "Unexpected server error"]);
}
?>
