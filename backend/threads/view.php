<?php
require_once 'config.php';
header('Content-Type: application/json');

$threadId = (int)$_GET['id'] ?? 0;
if (!$threadId) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid thread ID']);
    exit;
}

$stmt = $pdo->prepare("SELECT t.*, tc.name as category_name, u.username as creator_username, u.role as creator_role 
                       FROM threads t 
                       JOIN thread_categories tc ON t.category_id = tc.category_id 
                       JOIN users u ON t.created_by = u.id 
                       WHERE t.thread_id = ?");
$stmt->execute([$threadId]);
$thread = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$thread) {
    http_response_code(404);
    echo json_encode(['error' => 'Thread not found']);
    exit;
}

// Fetch comments (threaded)
$commStmt = $pdo->prepare("
    WITH RECURSIVE threaded_comments AS (
        SELECT comment_id, thread_id, parent_comment_id, commented_by, comment_body, image_url, created_at, 0 as level
        FROM thread_comments WHERE thread_id = ? AND parent_comment_id IS NULL
        UNION ALL
        SELECT c.comment_id, c.thread_id, c.parent_comment_id, c.commented_by, c.comment_body, c.image_url, c.created_at, tc.level + 1
        FROM thread_comments c
        JOIN threaded_comments tc ON c.parent_comment_id = tc.comment_id
        WHERE c.thread_id = ?
    )
    SELECT tc.*, u.username as commenter_username
    FROM threaded_comments tc
    JOIN users u ON tc.commented_by = u.id
    ORDER BY level, created_at
");
$commStmt->execute([$threadId, $threadId]);
$comments = $commStmt->fetchAll(PDO::FETCH_ASSOC);

// Fetch tags
$tagStmt = $pdo->prepare("SELECT tag_name FROM tags tt JOIN thread_tags tht ON tt.tag_id = tht.tag_id WHERE tht.thread_id = ?");
$tagStmt->execute([$threadId]);
$thread['tags'] = $tagStmt->fetchAll(PDO::FETCH_COLUMN);

// Update view count (if analytics enabled)
$anaStmt = $pdo->prepare("INSERT INTO thread_analytics (thread_id) VALUES (?) ON DUPLICATE KEY UPDATE total_views = total_views + 1");
$anaStmt->execute([$threadId]);

$thread['comments'] = $comments;
echo json_encode($thread);
?>