<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

require_once 'config.php';

ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL);

try {
    // Only POST allowed for security
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        echo json_encode(['error' => 'Invalid request method']);
        exit;
    }

    // Decode JSON
    $input = json_decode(file_get_contents('php://input'), true);

    $code = trim($input['code'] ?? '');

    if ($code === '') {
        echo json_encode(['error' => 'Invite code is required']);
        exit;
    }

    // Query private thread by invite code
    $sql = "
       SELECT 
    t.thread_id,
    t.title,
    t.body,
    t.category_id,
    c.name AS category_name,
    t.created_by,
    u.username AS creator_username,
    t.inspired_count,
    t.comment_count,
    t.collab_count,
    t.created_at,
    t.visibility,
    t.invite_code,
    GROUP_CONCAT(DISTINCT tg.tag_name SEPARATOR ',') AS tags
FROM threads t
LEFT JOIN thread_categories c ON t.category_id = c.category_id
LEFT JOIN users u ON t.created_by = u.id
LEFT JOIN thread_tags tt ON t.thread_id = tt.thread_id
LEFT JOIN tags tg ON tt.tag_id = tg.tag_id
WHERE t.visibility = 'private'
  AND BINARY t.invite_code = ?
GROUP BY t.thread_id
LIMIT 1;

    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([$code]);
    $thread = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$thread) {
        echo json_encode(['error' => 'Invalid or expired invite code']);
        exit;
    }

    // Convert tags string → array
    $thread['tags'] = $thread['tags'] ? explode(',', $thread['tags']) : [];

    // Build secure response
    $response = [
        'thread_id'        => (int)$thread['thread_id'],
        'title'            => $thread['title'],
        'body'             => $thread['body'],
        'category_name'    => $thread['category_name'],
        'creator_username' => $thread['creator_username'],
        'creator_role'     => $thread['creator_role'] ?? '',
        'inspired_count'   => (int)$thread['inspired_count'],
        'comment_count'    => (int)$thread['comment_count'],
        'collab_count'     => (int)$thread['collab_count'],
        'tags'             => $thread['tags'],
        'created_at'       => $thread['created_at'],
        'visibility'       => $thread['visibility'],
        'invite_code'      => $thread['invite_code'],
        'user_has_inspired'=> false
    ];

    echo json_encode($response);

} catch (PDOException $e) {
    error_log("[Invite Lookup Error] {$e->getMessage()}");
    echo json_encode(['error' => 'Database query failed']);
} catch (Throwable $e) {
    error_log("[General Error] {$e->getMessage()}");
    echo json_encode(['error' => 'Unexpected server error']);
}
?>
