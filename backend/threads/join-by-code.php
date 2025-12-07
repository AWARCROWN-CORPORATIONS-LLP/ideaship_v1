<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *'); 
header('Access-Control-Allow-Methods: GET, POST');
header('Access-Control-Allow-Headers: Content-Type');

require_once 'config.php';

ini_set('display_errors', 0);
error_reporting(E_ALL);

try {
    require_once'config.php';


  
    $input = json_decode(file_get_contents('php://input'), true) ?? $_GET;
    $code = trim($input['code'] ?? '');

    if (empty($code)) {
        echo json_encode(['error' => 'Invite code is required']);
        exit;
    }

    $sql = "
        SELECT 
            t.thread_id,
            t.title,
            t.body,
            t.category_id,
            c.name AS category_name,
            t.creator_username,
            u.role AS creator_role,
            t.inspired_count,
            t.comment_count,
            t.collab_count,
            t.created_at,
            t.visibility,
            t.invite_code,
            GROUP_CONCAT(DISTINCT tt.tag SEPARATOR ',') AS tags
        FROM threads t
        LEFT JOIN categories c ON t.category_id = c.category_id
        LEFT JOIN users u ON t.creator_username = u.username
        LEFT JOIN thread_tags tt ON t.thread_id = tt.thread_id
        WHERE t.visibility = 'private' 
          AND t.invite_code = ?
        GROUP BY t.thread_id
        LIMIT 1
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([$code]);

    $thread = $stmt->fetch();

    if (!$thread) {
        echo json_encode(['error' => 'Invalid or expired invite code']);
        exit;
    }

    
    $thread['tags'] = $thread['tags'] ? explode(',', $thread['tags']) : [];


    $response = [
        'thread_id' => (int)$thread['thread_id'],
        'title' => $thread['title'],
        'body' => $thread['body'],
        'category_name' => $thread['category_name'],
        'creator_username' => $thread['creator_username'],
        'creator_role' => $thread['creator_role'] ?? '',
        'inspired_count' => (int)$thread['inspired_count'],
        'comment_count' => (int)$thread['comment_count'],
        'collab_count' => (int)$thread['collab_count'],
        'tags' => $thread['tags'],
        'created_at' => $thread['created_at'],
        'user_has_inspired' => false, 
        'visibility' => $thread['visibility'],
        'invite_code' => $thread['invite_code']
    ];

    echo json_encode($response);

} catch (PDOException $e) {
    
    error_log("[Invite Lookup Error] " . $e->getMessage());
    echo json_encode(['error' => 'Database query failed']);
} catch (Exception $e) {
    error_log("[General Error] " . $e->getMessage());
    echo json_encode(['error' => 'Unexpected server error']);
}
?>
