<?php
header('Content-Type: application/json; charset=UTF-8');
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Pragma: no-cache");

ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/startup_error.log');
error_reporting(E_ALL & ~E_DEPRECATED);

require_once 'config.php';

try {
    $user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;

    // Dynamic joins only when user is logged in
    $followJoin = $user_id > 0
        ? "LEFT JOIN startup_follows sf ON sf.startup_id = sp.startup_id AND sf.user_id = :user_id"
        : "";

    $likeJoin = $user_id > 0
        ? "LEFT JOIN startup_likes sl ON sl.startup_id = sp.startup_id AND sl.user_id = :user_id"
        : "";

    $favoriteJoin = $user_id > 0
        ? "LEFT JOIN startup_favorites fav ON fav.startup_id = sp.startup_id AND fav.user_id = :user_id"
        : "";

    $query = "
        SELECT 
            sp.startup_id,
            sp.startup_name,
            sp.founders_names,
            sp.industry,
            sp.founding_date,
            sp.stage,
            sp.team_size,
            sp.business_vision,
            sp.funding_goals,
            sp.mentorship_needs,
            sp.linkedin,
            sp.instagram,
            sp.facebook,
            sp.followers_count,
            sp.likes_count,
            sp.favorites_count,
            sp.description,
            u.profile_picture,

            IF(sf.user_id IS NULL, 0, 1) AS is_following,
            IF(sl.user_id IS NULL, 0, 1) AS is_liked,
            IF(fav.user_id IS NULL, 0, 1) AS is_favorited

        FROM startup_profiles sp
        LEFT JOIN users u ON sp.user_id = u.id
        $followJoin
        $likeJoin
        $favoriteJoin

        ORDER BY sp.created_at DESC
    ";

    $stmt = $pdo->prepare($query);

    // Bind user ID if logged in
    if ($user_id > 0) {
        $stmt->bindValue(':user_id', $user_id, PDO::PARAM_INT);
    }

    $stmt->execute();
    $startups = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Convert numeric values to boolean
    foreach ($startups as &$row) {
        $row['is_following']  = ($row['is_following'] == 1);
        $row['is_liked']      = ($row['is_liked'] == 1);
        $row['is_favorited']  = ($row['is_favorited'] == 1);

        $row['followers_count']  = intval($row['followers_count']);
        $row['likes_count']      = intval($row['likes_count']);
        $row['favorites_count']  = intval($row['favorites_count']);
    }
    unset($row);

    echo json_encode([
        'success' => true,
        'startups' => $startups
    ]);

} catch (Exception $e) {
    error_log("DB Error: " . $e->getMessage());
    echo json_encode(['success' => false, 'message' => 'Database error']);
}
?>
