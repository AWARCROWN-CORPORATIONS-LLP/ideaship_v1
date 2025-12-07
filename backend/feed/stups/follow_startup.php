<?php
header('Content-Type: application/json');
include 'config.php'; // contains $pdo (PDO connection)

try {
    if (!isset($_POST['user_id'], $_POST['startup_id'], $_POST['action'])) {
        $msg = 'Missing POST parameters';
        error_log("[FOLLOW_ERROR] $msg | POST: " . json_encode($_POST));
        echo json_encode(['success' => false, 'message' => $msg]);
        exit;
    }

    $user_id = intval($_POST['user_id']);
    $startup_id = intval($_POST['startup_id']);
    $action = $_POST['action'];

    // FOLLOW
    if ($action === 'follow') {
        // Insert follow
        $sql = "INSERT INTO startup_follows (user_id, startup_id) VALUES (:user_id, :startup_id)";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':user_id' => $user_id,
            ':startup_id' => $startup_id
        ]);

        // Increase follower count
        $updateSql = "UPDATE startup_profiles SET followers_count = followers_count + 1 WHERE startup_id = :startup_id";
        $updateStmt = $pdo->prepare($updateSql);
        $updateStmt->execute([':startup_id' => $startup_id]);
    }

    // UNFOLLOW
    else {
        // Delete follow
        $sql = "DELETE FROM startup_follows WHERE user_id = :user_id AND startup_id = :startup_id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':user_id' => $user_id,
            ':startup_id' => $startup_id
        ]);

        // Decrease follower count (protect from negative)
        $updateSql = "UPDATE startup_profiles 
                      SET followers_count = GREATEST(followers_count - 1, 0) 
                      WHERE startup_id = :startup_id";

        $updateStmt = $pdo->prepare($updateSql);
        $updateStmt->execute([':startup_id' => $startup_id]);
    }

    echo json_encode(['success' => true]);

} catch (PDOException $e) {
    $msg = "PDO Error: " . $e->getMessage();
    error_log("[FOLLOW_EXCEPTION] $msg");
    echo json_encode(['success' => false, 'message' => $msg]);
}
?>
