<?php
session_start();
require_once 'config.php'; // must return $pdo (PDO connection)

// JSON header
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

function logError($message, $details = []) {
    $logMessage = date('Y-m-d H:i:s') . " - Error: $message - Details: " . json_encode($details) . "\n";
    file_put_contents(__DIR__ . '/error.log', $logMessage, FILE_APPEND);
    error_log($logMessage);
}

// ✅ Validate input
if (!isset($_GET['post_id']) || !is_numeric($_GET['post_id'])) {
    http_response_code(400);
    echo json_encode(["error" => "Invalid or missing Post ID", "code" => "INVALID_POST_ID"]);
    exit();
}
if (empty($_GET['username'])) {
    http_response_code(400);
    echo json_encode(["error" => "Missing username", "code" => "INVALID_USERNAME"]);
    exit();
}

$post_id  = (int)$_GET['post_id'];
$username = trim($_GET['username']);

try {
    if (!$pdo) throw new Exception("Database connection failed");

    // ✅ Fetch user_id from username
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $stmt->execute([$username]);
    $userRow = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$userRow) {
        http_response_code(404);
        echo json_encode(["error" => "User not found", "code" => "USER_NOT_FOUND"]);
        exit();
    }
    $current_user = (int)$userRow['id'];

    // ✅ Check if post exists
    $stmt = $pdo->prepare("SELECT COUNT(*) as post_count FROM posts WHERE post_id=?");
    $stmt->execute([$post_id]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($row['post_count'] == 0) {
        http_response_code(404);
        echo json_encode(["error"=>"Post not found","code"=>"POST_NOT_FOUND"]);
        exit();
    }

    // ✅ Fetch comments only (no hot_score update here)
    $stmt = $pdo->prepare("
        SELECT 
            c.comment_id, 
            c.comment, 
            c.created_at, 
            c.updated_at, 
            c.user_id,
            c.parent_comment_id,
            u.username,
            COALESCE(u.profile_picture,'default-profile.png') AS profile_picture,
            COUNT(r.reaction_id) AS like_count,
            MAX(CASE WHEN r.user_id=? THEN r.reaction_type END) AS current_reaction
        FROM post_comments c
        JOIN users u ON c.user_id = u.id
        LEFT JOIN comment_reactions r ON c.comment_id = r.comment_id
        WHERE c.post_id=?
        GROUP BY c.comment_id
        ORDER BY c.created_at ASC
    ");
    $stmt->execute([$current_user, $post_id]);

    $comments = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $comments[] = [
            "comment_id"       => (int)$row['comment_id'],
            "comment"          => htmlspecialchars($row['comment'], ENT_QUOTES, 'UTF-8'),
            "created_at"       => $row['created_at'],
            "updated_at"       => $row['updated_at'],
            "username"         => $row['username'],
            "profile_picture"  => $row['profile_picture'],
            "user_id"          => (int)$row['user_id'],
            "parent_comment_id"=> $row['parent_comment_id'] ? (int)$row['parent_comment_id'] : null,
            "like_count"       => (int)$row['like_count'],
            "current_reaction" => $row['current_reaction'] ?? null
        ];
    }

    echo json_encode([
        "comments"   => $comments,
        "status"     => "success",
        "count"      => count($comments),
        "user_id"    => $current_user
    ]);

} catch(Exception $e) {
    logError("Failed to fetch comments", [
        "post_id"=>$post_id,
        "username"=>$username,
        "error"=>$e->getMessage(),
        "trace"=>$e->getTraceAsString()
    ]);
    http_response_code(500);
    echo json_encode(["error" => "Internal Server Error", "code" => "DATABASE_ERROR"]);
}
?>