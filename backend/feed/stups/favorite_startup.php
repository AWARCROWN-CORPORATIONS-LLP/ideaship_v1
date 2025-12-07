<?php
header('Content-Type: application/json');
require_once 'config.php'; // MUST create $pdo

try {
    if (!isset($_POST['user_id'], $_POST['startup_id'], $_POST['action'])) {
        echo json_encode(['success' => false, 'message' => 'Missing POST parameters']);
        exit;
    }

    $user_id = intval($_POST['user_id']);
    $startup_id = intval($_POST['startup_id']);
    $action = $_POST['action'];

    // -----------------------------------------
    // FAVORITE
    // -----------------------------------------
    if ($action === 'favorite') {

        // Insert favorite (ignore if duplicate)
        $sql = "
            INSERT IGNORE INTO startup_favorites (user_id, startup_id)
            VALUES (:user_id, :startup_id)
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':user_id' => $user_id,
            ':startup_id' => $startup_id
        ]);

        // Increase favorites_count
        $update = $pdo->prepare("
            UPDATE startup_profiles
            SET favorites_count = favorites_count + 1
            WHERE startup_id = :startup_id
        ");
        $update->execute([':startup_id' => $startup_id]);

    } 
    // -----------------------------------------
    // UNFAVORITE
    // -----------------------------------------
    else if ($action === 'unfavorite') {

        // Remove favorite
        $sql = "
            DELETE FROM startup_favorites
            WHERE user_id = :user_id AND startup_id = :startup_id
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':user_id' => $user_id,
            ':startup_id' => $startup_id
        ]);

        // Decrease favorites_count (never below 0)
        $update = $pdo->prepare("
            UPDATE startup_profiles
            SET favorites_count = GREATEST(favorites_count - 1, 0)
            WHERE startup_id = :startup_id
        ");
        $update->execute([':startup_id' => $startup_id]);

    } 
    else {
        echo json_encode(['success' => false, 'message' => 'Invalid action']);
        exit;
    }

    echo json_encode(['success' => true]);

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
