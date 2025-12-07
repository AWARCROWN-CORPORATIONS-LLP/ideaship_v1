<?php
header('Content-Type: application/json');
require_once 'config.php';  // Provides $pdo

$target_username = $_GET['username'] ?? '';
$current_username = $_GET['current_username'] ?? '';

if (!$target_username) {
    echo json_encode(['error' => 'username required']);
    exit;
}

try {
    // Get target user ID
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $stmt->execute([$target_username]);
    $target = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$target) {
        echo json_encode(['error' => 'User not found']);
        exit;
    }

    $target_id = $target['id'];

    // Get current viewer user ID (to check is_following)
    $current_id = 0;
    if (!empty($current_username)) {
        $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
        $stmt->execute([$current_username]);
        $current = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($current) {
            $current_id = $current['id'];
        }
    }

    // Fetch following list
    $sql = "
        SELECT 
            u.id AS user_id,
            u.username,
            u.profile_picture,
            CASE 
                WHEN f2.follower_id = :current_id THEN 1 
                ELSE 0 
            END AS is_following
        FROM follows f
        JOIN users u ON u.id = f.followed_id
        LEFT JOIN follows f2 
            ON f2.followed_id = u.id AND f2.follower_id = :current_id
        WHERE f.follower_id = :target_id
        ORDER BY u.username ASC
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':target_id' => $target_id,
        ':current_id' => $current_id
    ]);

    $following = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'following' => $following
    ]);

} catch (PDOException $e) {
    echo json_encode(['error' => 'database error']);
    exit;
}
?>
