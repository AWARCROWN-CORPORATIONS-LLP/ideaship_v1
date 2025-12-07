<?php
include 'config.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(["status" => "error", "message" => "Invalid request"]);
    exit;
}

if (!isset($_POST['comment_id'], $_POST['user_id'], $_POST['action'])) {
    echo json_encode(["status" => "error", "message" => "Missing parameters"]);
    exit;
}

$comment_id = intval($_POST['comment_id']);
$user_id = intval($_POST['user_id']);
$action = $_POST['action'];

// -----------------------------
// ADD REACTION (like)
// -----------------------------
if ($action === 'like') {

    // Insert or update like
    $stmt = $pdo->prepare("
        INSERT INTO comment_likes (comment_id, user_id, reaction_type, created_at)
        VALUES (:cid, :uid, 'like', NOW())
        ON DUPLICATE KEY UPDATE reaction_type = 'like', created_at = NOW()
    ");

    $stmt->execute([
        ':cid' => $comment_id,
        ':uid' => $user_id
    ]);

    $is_liked = true;
}

// -----------------------------
// REMOVE REACTION (unlike)
// -----------------------------
elseif ($action === 'unlike') {

    $stmt = $pdo->prepare("DELETE FROM comment_likes WHERE comment_id = :cid AND user_id = :uid");
    $stmt->execute([
        ':cid' => $comment_id,
        ':uid' => $user_id
    ]);

    $is_liked = false;
}

else {
    echo json_encode(["status" => "error", "message" => "Invalid action"]);
    exit;
}

// -----------------------------
// FETCH NEW LIKE COUNT
// -----------------------------
$countStmt = $pdo->prepare("SELECT COUNT(*) FROM comment_likes WHERE comment_id = :cid");
$countStmt->execute([':cid' => $comment_id]);
$like_count = intval($countStmt->fetchColumn());

// -----------------------------
// SEND RESPONSE
// -----------------------------
echo json_encode([
    "status" => "success",
    "is_liked" => $is_liked,
    "like_count" => $like_count
]);

exit;
?>
