<?php
require_once 'config.php';
header('Content-Type: application/json; charset=UTF-8');
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Pragma: no-cache");
header("Expires: 0");

// Enable detailed error logging
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL);

/**
 * Helper: Send JSON response and exit
 */
function send_json(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

try {
    $input = json_decode(file_get_contents('php://input'), true);
    $category   = $input['category'] ?? null;
    $title      = $input['title'] ?? null;
    $body       = $input['body'] ?? null;
    $visibility = $input['visibility'] ?? 'public';
    $username   = $input['username'] ?? null; // From SharedPrefs or frontend

    // --- Validate required fields ---
    if (!$category || !$title || !$body || !$username || !in_array($visibility, ['public', 'private'], true)) {
        send_json(['error' => 'Missing or invalid fields'], 400);
    }

    // --- Fetch user ---
    $userStmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $userStmt->execute([$username]);
    $userId = $userStmt->fetchColumn();
    if (!$userId) {
        send_json(['error' => 'User not found'], 404);
    }

    // --- Fetch category ---
    $catStmt = $pdo->prepare("SELECT category_id FROM thread_categories WHERE name = ?");
    $catStmt->execute([$category]);
    $categoryId = $catStmt->fetchColumn();
    if (!$categoryId) {
        send_json(['error' => 'Invalid category'], 400);
    }

    // --- Generate invite code for private threads ---
    $inviteCode = ($visibility === 'private')
        ? strtoupper(substr(md5(uniqid('', true)), 0, 8))
        : null;

    // --- Insert thread ---
    $pdo->beginTransaction();
    $threadStmt = $pdo->prepare("
        INSERT INTO threads (category_id, created_by, title, body, visibility, invite_code, status)
        VALUES (?, ?, ?, ?, ?, ?, 'active')
    ");
    $threadStmt->execute([$categoryId, $userId, $title, $body, $visibility, $inviteCode]);
    $threadId = $pdo->lastInsertId();

    // --- Add tags (if provided) ---
    if (!empty($input['tags']) && is_array($input['tags'])) {
        foreach ($input['tags'] as $tagName) {
            try {
                $pdo->prepare("INSERT IGNORE INTO tags (tag_name) VALUES (?)")->execute([$tagName]);
                $tagId = $pdo->prepare("SELECT tag_id FROM tags WHERE tag_name = ?");
                $tagId->execute([$tagName]);
                $tag = $tagId->fetchColumn();

                if ($tag) {
                    $pdo->prepare("INSERT IGNORE INTO thread_tags (thread_id, tag_id) VALUES (?, ?)")
                        ->execute([$threadId, $tag]);
                }
            } catch (Throwable $tagErr) {
                error_log("[Tag Insert Error] {$tagErr->getMessage()} for tag '{$tagName}'");
            }
        }
    }

    $pdo->commit();

    send_json([
        'success'      => true,
        'thread_id'    => $threadId,
        'visibility'   => $visibility,
        'invite_code'  => $inviteCode
    ]);

} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log("[Thread Creation Error] {$e->getMessage()} in {$e->getFile()}:{$e->getLine()}");
    send_json(['error' => 'Internal Server Error'], 500);
}
?>
