<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
require '../database/config.php';
session_start();

header("Content-Type: application/json");

if (!isset($_SESSION['username'])) {
    echo json_encode(["status" => "error", "message" => "Unauthorized"]);
    exit();
}

if (isset($_GET['comment_id'])) {
    $comment_id = intval($_GET['comment_id']);
    $reporter = $_SESSION['username'];

    // Check if the user has already reported this comment
    $stmt = $conn->prepare("SELECT id FROM reports_comments WHERE comment_id = ? AND reporter = ?");
    $stmt->bind_param("is", $comment_id, $reporter);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        echo json_encode(["alreadyReported" => true]);
    } else {
        echo json_encode(["alreadyReported" => false]);
    }

    $stmt->close();
    exit();
}

echo json_encode(["status" => "error", "message" => "Invalid request"]);
exit();
?>
