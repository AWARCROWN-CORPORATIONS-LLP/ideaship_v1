<?php
header('Content-Type: application/json');
require_once 'config.php'; // must create $pdo (PDO)

try {
    if (!isset($_POST['user_id'], $_POST['startup_id'], $_POST['action'])) {
        echo json_encode(['success' => false, 'message' => 'Missing POST parameters']);
        exit;
    }

    $user_id = intval($_POST['user_id']);
    $startup_id = intval($_POST['startup_id']);
    $action = $_POST['action'];

    // LIKE
    if ($action === 'like') {

        // Insert like
        $sql = "INSERT INTO startup_likes (user_id, startup_id) VALUES (:user_id, :startup_id)";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':user_id' => $user_id,
            ':startup_id' => $startup_id
        ]);

        // Update like count (+1)
        $update = $pdo->prepare("
            UPDATE startup_profiles 
            SET likes_count = likes_count + 1 
            WHERE startup_id = :startup_id
        ");
        $update->execute([':startup_id' => $startup_id]);

    } 
    // UNLIKE
    else {

        // Delete like
        $sql = "DELETE FROM startup_likes WHERE user_id = :user_id AND startup_id = :startup_id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':user_id' => $user_id,
            ':startup_id' => $startup_id
        ]);

        // Update like count (decrease but never below 0)
        $update = $pdo->prepare("
            UPDATE startup_profiles 
            SET likes_count = GREATEST(likes_count - 1, 0)
            WHERE startup_id = :startup_id
        ");
        $update->execute([':startup_id' => $startup_id]);
    }

    echo json_encode(['success' => true]);

} catch (PDOException $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
