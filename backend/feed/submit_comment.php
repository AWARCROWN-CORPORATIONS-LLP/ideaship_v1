<?php
// submit_comments.php
session_start();
require_once 'config.php'; // must return $pdo (PDO connection)

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$username = $_POST['username'] ?? "Anonymous";

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['post_id'], $_POST['comment'])) {
    $post_id = (int)$_POST['post_id'];
    $comment = trim($_POST['comment']);
    $parent_comment_id = !empty($_POST['parent_comment_id']) ? (int)$_POST['parent_comment_id'] : null;

    if ($comment === '') {
        error_log("submit_comments.php - Empty comment submitted. Username: $username, Post ID: $post_id");
        echo json_encode(["status" => "error", "message" => "Comment cannot be empty."]);
        exit();
    }

    try {
        // ✅ Fetch user_id by username
        $stmtUser = $pdo->prepare("SELECT id FROM users WHERE username = ?");
        $stmtUser->execute([$username]);
        $userRow = $stmtUser->fetch(PDO::FETCH_ASSOC);

        if (!$userRow) {
            error_log("submit_comments.php - User not found for username: $username");
            echo json_encode(["status" => "error", "message" => "User not found."]);
            exit();
        }
        $user_id = (int)$userRow['id'];

        // ✅ Insert comment
        if ($parent_comment_id === null) {
            $stmt = $pdo->prepare("
                INSERT INTO post_comments (post_id, user_id, comment, created_at) 
                VALUES (?, ?, ?, NOW())
            ");
            $success = $stmt->execute([$post_id, $user_id, $comment]);
        } else {
            $stmt = $pdo->prepare("
                INSERT INTO post_comments (post_id, user_id, parent_comment_id, comment, created_at) 
                VALUES (?, ?, ?, ?, NOW())
            ");
            $success = $stmt->execute([$post_id, $user_id, $parent_comment_id, $comment]);
        }

        if (!$success) {
            error_log("submit_comments.php - Failed to insert comment. Username: $username, User ID: $user_id, Post ID: $post_id");
            echo json_encode(["status" => "error", "message" => "Failed to save comment."]);
            exit();
        }

        $comment_id = $pdo->lastInsertId();

        // ✅ Increment comment count in posts
        $updateCount = $pdo->prepare("UPDATE posts SET comment_count = comment_count + 1 WHERE post_id = ?");
        $updateCount->execute([$post_id]);

        // ✅ Recalculate hot_score
        $stmt = $pdo->prepare("SELECT like_count, comment_count, share_count, created_at FROM posts WHERE post_id=?");
        $stmt->execute([$post_id]);
        $post = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($post) {
            $likes = (int)$post['like_count'];
            $comments = (int)$post['comment_count'];
            $shares = (int)$post['share_count'];
            $createdAt = new DateTime($post['created_at']);
            $hours = max(0, (new DateTime())->diff($createdAt)->h + 24 * $createdAt->diff(new DateTime())->days);

            $score = ($likes * 1.0 + $comments * 0.5 + $shares * 2.0) / pow($hours + 2, 1.2);

            $updateScore = $pdo->prepare("UPDATE posts SET hot_score=? WHERE post_id=?");
            $updateScore->execute([$score, $post_id]);
        }

        // ✅ Fetch timestamp + profile picture
        $fetchStmt = $pdo->prepare("
            SELECT c.created_at, u.profile_picture 
            FROM post_comments c 
            JOIN users u ON c.user_id = u.id 
            WHERE c.comment_id = ?
        ");
        $fetchStmt->execute([$comment_id]);
        $row = $fetchStmt->fetch(PDO::FETCH_ASSOC);

        $profile_picture = $row['profile_picture'] ?? "default-profile.png";

        echo json_encode([
            "status"            => "success",
            "comment_id"        => $comment_id,
            "username"          => $username,
            "comment"           => htmlspecialchars($comment, ENT_QUOTES, 'UTF-8'),
            "created_at"        => $row['created_at'],
            "updated_at"        => null,
            "isOwner"           => true,
            "parent_comment_id" => $parent_comment_id,
            "like_count"        => 0,
            "current_reaction"  => null,
            "profile_picture"   => $profile_picture,
            "user_id"           => $user_id
        ]);
        exit;

    } catch (PDOException $e) {
        error_log("submit_comments.php - PDOException: " . $e->getMessage());
        echo json_encode(["status" => "error", "message" => "Database error."]);
        exit();
    }
}

error_log("submit_comments.php - Invalid request method or missing params. Username: $username");
echo json_encode(["status" => "error", "message" => "Invalid request"]);
