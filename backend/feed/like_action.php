<?php
include 'config.php'; // must return $pdo (PDO connection)

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

// Error handler → log details, show clean message
set_error_handler(function($severity, $message, $file, $line) {
    error_log("PHP Error [{$severity}] {$message} in {$file} on line {$line}");
    http_response_code(500);
    echo json_encode(["error" => "Internal server error"]);
    exit;
});

try {
    if (!isset($_POST['user_id']) || !isset($_POST['post_id'])) {
        http_response_code(400);
        echo json_encode(["error" => "Missing user_id or post_id"]);
        exit;
    }

    $user_id = intval($_POST['user_id']);
    $post_id = intval($_POST['post_id']);

    if ($user_id <= 0 || $post_id <= 0) {
        http_response_code(400);
        echo json_encode(["error" => "Invalid user_id or post_id"]);
        exit;
    }

    // Check if already liked
    $stmt = $pdo->prepare("SELECT 1 FROM post_likes WHERE post_id = ? AND user_id = ?");
    if (!$stmt->execute([$post_id, $user_id])) {
        error_log("Failed to check like: " . implode(" | ", $stmt->errorInfo()));
        throw new Exception("Database query failed");
    }

    $is_liked = false;

    if ($stmt->fetch()) {
        // Unlike
        $delete_stmt = $pdo->prepare("DELETE FROM post_likes WHERE post_id = ? AND user_id = ?");
        if (!$delete_stmt->execute([$post_id, $user_id])) {
            error_log("Failed to delete like: " . implode(" | ", $delete_stmt->errorInfo()));
            throw new Exception("Database delete failed");
        }

        $update_stmt = $pdo->prepare("UPDATE posts SET like_count = like_count - 1 WHERE post_id = ?");
        if (!$update_stmt->execute([$post_id])) {
            error_log("Failed to decrement like_count: " . implode(" | ", $update_stmt->errorInfo()));
            throw new Exception("Database update failed");
        }

        $is_liked = false; // user has unliked
    } else {
        // Like
        $insert_stmt = $pdo->prepare("INSERT INTO post_likes (post_id, user_id) VALUES (?, ?)");
        if (!$insert_stmt->execute([$post_id, $user_id])) {
            error_log("Failed to insert like: " . implode(" | ", $insert_stmt->errorInfo()));
            throw new Exception("Database insert failed");
        }

        $update_stmt = $pdo->prepare("UPDATE posts SET like_count = like_count + 1 WHERE post_id = ?");
        if (!$update_stmt->execute([$post_id])) {
            error_log("Failed to increment like_count: " . implode(" | ", $update_stmt->errorInfo()));
            throw new Exception("Database update failed");
        }

        $is_liked = true; // user has liked
    }

    // Fetch updated like count
    $count_stmt = $pdo->prepare("SELECT like_count FROM posts WHERE post_id = ?");
    if (!$count_stmt->execute([$post_id])) {
        error_log("Failed to fetch like_count: " . implode(" | ", $count_stmt->errorInfo()));
        throw new Exception("Database fetch failed");
    }
    $like_count = $count_stmt->fetchColumn();

    echo json_encode([
        "like_count" => $like_count ?: 0,
        "is_liked"   => $is_liked
    ]);

} catch (Exception $e) {
    error_log("Exception: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(["error" => "Internal server error"]);
}
