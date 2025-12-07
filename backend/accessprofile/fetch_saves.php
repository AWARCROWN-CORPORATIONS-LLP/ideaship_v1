<?php
header('Content-Type: application/json');
require_once 'config.php'; // contains $pdo

// -----------------------------
// ERROR LOGGING
// -----------------------------
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL);

// -----------------------------
// ENCRYPTION CONSTANTS
// -----------------------------
define("ENCRYPTION_KEY", base64_decode("7/bUxXBcXrgqyASvQSbLSKNce+rvWJt0botpIrA4poQ="));
define("ENCRYPTION_METHOD", "AES-256-CBC");

// -----------------------------
// DECRYPT FUNCTION
// -----------------------------
function decryptData($data) {
    try {
        if (!$data) return null;
        $decodedData = base64_decode($data);
        if ($decodedData === false || strpos($decodedData, "::") === false) return null;

        list($encryptedData, $iv) = explode("::", $decodedData, 2);

        $decrypted = openssl_decrypt(
            $encryptedData,
            ENCRYPTION_METHOD,
            ENCRYPTION_KEY,
            0,
            $iv
        );

        return $decrypted ?: null;

    } catch (Exception $e) {
        error_log("Decrypt error: " . $e->getMessage());
        return null;
    }
}

try {

    // -----------------------------
    // INPUT VALIDATION
    // -----------------------------
    $username = $_GET['username'] ?? '';
    $cursorId = isset($_GET['cursorId']) ? intval($_GET['cursorId']) : null;
    $limit = 10;

    if (!$username) {
        echo json_encode(['error' => 'username is required']);
        exit;
    }

    // -----------------------------
    // GET USER ID
    // -----------------------------
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $stmt->execute([$username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        echo json_encode(['error' => 'User not found']);
        exit;
    }

    $userId = $user['id'];

    // -----------------------------
    // BUILD PAGINATION QUERY
    // -----------------------------
    $sql = "
        SELECT 
            p.post_id,
            p.content,
            p.media_url,
            p.created_at,
            u.username,
            u.profile_picture,
            p.like_count,
            p.comment_count
        FROM saves s
        JOIN posts p ON p.post_id = s.post_id
        JOIN users u ON u.id = p.user_id
        WHERE s.user_id = :userId
    ";

    if ($cursorId) {
        $sql .= " AND s.post_id < :cursorId ";
    }

    $sql .= "
        ORDER BY s.post_id DESC
        LIMIT :limit
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':userId', $userId, PDO::PARAM_INT);

    if ($cursorId) {
        $stmt->bindValue(':cursorId', $cursorId, PDO::PARAM_INT);
    }

    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);

    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // -----------------------------
    // FORMAT OUTPUT + DECRYPT MEDIA
    // -----------------------------
    $posts = array_map(function($row) {

        return [
            'post_id' => (int)$row['post_id'],
            'content' => $row['content'],
            'media_url' => decryptData($row['media_url']), // <<<<<< DECRYPTED HERE
            'created_at' => $row['created_at'],
            'username' => $row['username'],
            'profile_picture' => $row['profile_picture'],
            'like_count' => (int)$row['like_count'],
            'comment_count' => (int)$row['comment_count']
        ];

    }, $rows);

    // -----------------------------
    // NEXT CURSOR
    // -----------------------------
    $nextCursorId = null;
    if (count($posts) === $limit) {
        $last = end($posts);
        $nextCursorId = $last['post_id'];
    }

    echo json_encode([
        'success' => true,
        'posts' => $posts,
        'nextCursorId' => $nextCursorId
    ]);

} catch (PDOException $e) {
    echo json_encode([
        'error' => 'database error',
        'details' => $e->getMessage()
    ]);
}
?>
