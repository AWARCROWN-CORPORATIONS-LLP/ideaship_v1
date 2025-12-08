<?php
require_once 'config.php';
header('Content-Type: application/json; charset=UTF-8');
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Pragma: no-cache");
header("Expires: 0");

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

/**
 * Generate a human-friendly professional invite code
 * Example: RT-9XG7-PLK3
 */
function generateProfessionalInviteCode(): string {
    $prefix = "RT"; // RoundTable code prefix
    $part1 = strtoupper(substr(bin2hex(random_bytes(2)), 0, 4));
    $part2 = strtoupper(substr(bin2hex(random_bytes(2)), 0, 4));
    return "$prefix-$part1-$part2";
}

/**
 * Generate encrypted-looking code (optional)
 * Example: X9F7KL2PQM
 */
function generateEncryptedInviteCode(): string {
    $allowed = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O, I, 0, 1
    $code = '';
    for ($i = 0; $i < 10; $i++) {
        $code .= $allowed[random_int(0, strlen($allowed) - 1)];
    }
    return $code;
}

/**
 * Generate a unique invite code (checks DB for duplicates)
 * mode: PROFESSIONAL or ENCRYPTED
 */
function generateUniqueInviteCode(PDO $pdo, string $mode = 'PROFESSIONAL'): string {
    do {
        $code = ($mode === 'ENCRYPTED')
            ? generateEncryptedInviteCode()
            : generateProfessionalInviteCode();

        $check = $pdo->prepare("SELECT thread_id FROM threads WHERE invite_code = ? LIMIT 1");
        $check->execute([$code]);
        $exists = $check->fetchColumn();
    } while ($exists);

    return $code;
}

try {
    $input = json_decode(file_get_contents('php://input'), true);

    $category   = $input['category']   ?? null;
    $title      = $input['title']      ?? null;
    $body       = $input['body']       ?? null;
    $visibility = $input['visibility'] ?? 'public';
    $username   = $input['username']   ?? null;

    // Validate fields
    if (!$category || !$title || !$body || !$username || !in_array($visibility, ['public', 'private'], true)) {
        send_json(['error' => 'Missing or invalid fields'], 400);
    }

    // Fetch user
    $userStmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $userStmt->execute([$username]);
    $userId = $userStmt->fetchColumn();
    if (!$userId) {
        send_json(['error' => 'User not found'], 404);
    }

    // Fetch category
    $catStmt = $pdo->prepare("SELECT category_id FROM thread_categories WHERE name = ?");
    $catStmt->execute([$category]);
    $categoryId = $catStmt->fetchColumn();
    if (!$categoryId) {
        send_json(['error' => 'Invalid category'], 400);
    }

    // --------- Generate INVITE CODE (Professional Style) ----------
    $inviteCode = null;
    if ($visibility === 'private') {
        // Choose PROFESSIONAL or ENCRYPTED
        $inviteCode = generateUniqueInviteCode($pdo, 'PROFESSIONAL');
    }

    // Insert thread
    $pdo->beginTransaction();
    $threadStmt = $pdo->prepare("
        INSERT INTO threads (category_id, created_by, title, body, visibility, invite_code, status)
        VALUES (?, ?, ?, ?, ?, ?, 'active')
    ");
    $threadStmt->execute([$categoryId, $userId, $title, $body, $visibility, $inviteCode]);
    $threadId = $pdo->lastInsertId();

    // Insert tags if provided
    if (!empty($input['tags']) && is_array($input['tags'])) {
        foreach ($input['tags'] as $tagName) {
            try {
                $pdo->prepare("INSERT IGNORE INTO tags (tag_name) VALUES (?)")->execute([$tagName]);

                $tagFetch = $pdo->prepare("SELECT tag_id FROM tags WHERE tag_name = ?");
                $tagFetch->execute([$tagName]);
                $tagId = $tagFetch->fetchColumn();

                if ($tagId) {
                    $pdo->prepare("INSERT IGNORE INTO thread_tags (thread_id, tag_id) VALUES (?, ?)")
                        ->execute([$threadId, $tagId]);
                }
            } catch (Throwable $ex) {
                error_log("[Tag Insert Error] {$ex->getMessage()} for tag '{$tagName}'");
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
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log("[Thread Creation Error] {$e->getMessage()} in {$e->getFile()}:{$e->getLine()}");
    send_json(['error' => 'Internal Server Error'], 500);
}
?>
