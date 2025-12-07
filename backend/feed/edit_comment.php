<?php
// edit_comment.php
session_start();
include 'config.php';

header('Content-Type: application/json');

if (!isset($_SESSION['user_id'])) {
    echo json_encode(["status" => "error", "message" => "Unauthorized"]);
    exit();
}

$user_id = $_SESSION['user_id'];

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['comment_id'], $_POST['comment'])) {
    $comment_id = intval($_POST['comment_id']);
    $comment = trim($_POST['comment']);

    if (empty($comment)) {
        echo json_encode(["status" => "error", "message" => "Comment cannot be empty"]);
        exit();
    }

    // Check ownership
    $checkStmt = $conn->prepare("SELECT user_id FROM post_comments WHERE comment_id = ?");
    $checkStmt->bind_param("i", $comment_id);
    $checkStmt->execute();
    $result = $checkStmt->get_result();
    if ($row = $result->fetch_assoc()) {
        if ($row['user_id'] !== $user_id) {
            echo json_encode(["status" => "error", "message" => "Not your comment"]);
            exit();
        }
    } else {
        echo json_encode(["status" => "error", "message" => "Comment not found"]);
        exit();
    }
    $checkStmt->close();

    $stmt = $conn->prepare("UPDATE post_comments SET comment = ?, updated_at = NOW() WHERE comment_id = ?");
    $stmt->bind_param("si", $comment, $comment_id);
    if ($stmt->execute()) {
        echo json_encode(["status" => "success"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to update"]);
    }
    $stmt->close();
    exit();
}

echo json_encode(["status" => "error", "message" => "Invalid request"]);
?>