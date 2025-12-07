<?php
require_once 'config.php';
header('Content-Type: application/json; charset=UTF-8');
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Pragma: no-cache");
header("Expires: 0");

// --- Enable and configure error logging ---
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL);

// --- Custom error handler ---
set_error_handler(function ($severity, $message, $file, $line) {
    $logMessage = sprintf(
        "[%s] PHP Error [%d]: %s in %s:%d\n",
        date('Y-m-d H:i:s'), $severity, $message, $file, $line
    );
    error_log($logMessage);
    if (in_array($severity, [E_ERROR, E_USER_ERROR])) {
        http_response_code(500);
        echo json_encode(['error' => 'A server error occurred']);
        exit;
    }
});

// --- Custom exception handler ---
set_exception_handler(function ($e) {
    $logMessage = sprintf(
        "[%s] Uncaught Exception: %s in %s:%d\nStack trace:\n%s\n",
        date('Y-m-d H:i:s'),
        $e->getMessage(),
        $e->getFile(),
        $e->getLine(),
        $e->getTraceAsString()
    );
    error_log($logMessage);
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected internal error']);
    exit;
});

// --- Helper for safe JSON responses ---
function send_json(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

try {
    // --- Validate inputs ---
    $threadId = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);
    $input = json_decode(file_get_contents('php://input'), true);

    $action = $input['type'] ?? 'inspired'; // inspired | uninspired | check
    $username = trim($input['username'] ?? '');
    $code = $input['code'] ?? $_GET['code'] ?? null;

    error_log(sprintf("[%s] Request received: action=%s, threadId=%s, username=%s",
        date('Y-m-d H:i:s'), $action, $threadId, $username
    ));

    if (!$threadId || !$username || !in_array($action, ['inspired', 'uninspired', 'check'], true)) {
        send_json(['error' => 'Invalid or missing parameters'], 400);
    }

    // --- Fetch user ID ---
    $userStmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $userStmt->execute([$username]);
    $userId = $userStmt->fetchColumn();

    if (!$userId) {
        send_json(['error' => 'User not found'], 404);
    }

    // --- Validate thread access ---
    $threadStmt = $pdo->prepare("SELECT visibility, invite_code, created_by, title FROM threads WHERE thread_id = ?");
    $threadStmt->execute([$threadId]);
    $thread = $threadStmt->fetch(PDO::FETCH_ASSOC);

    if (!$thread) {
        send_json(['error' => 'Thread not found'], 404);
    }
    if ($thread['visibility'] === 'private' && $code !== $thread['invite_code']) {
        send_json(['error' => 'Access denied - invalid code'], 403);
    }

    $reactionType = 'inspired';
    $response = ['user_has_inspired' => false, 'inspired_count' => 0];

    // --- Check-only mode ---
    if ($action === 'check') {
        $checkStmt = $pdo->prepare("
            SELECT EXISTS(
                SELECT 1 FROM thread_reactions WHERE thread_id = ? AND reacted_by = ? AND type = ?
            )
        ");
        $checkStmt->execute([$threadId, $userId, $reactionType]);
        $exists = (bool)$checkStmt->fetchColumn();

        $countStmt = $pdo->prepare("SELECT inspired_count FROM threads WHERE thread_id = ?");
        $countStmt->execute([$threadId]);
        $count = (int)($countStmt->fetchColumn() ?: 0);

        send_json([
            'user_has_inspired' => $exists,
            'inspired_count' => $count
        ]);
    }

    // --- Start transaction ---
    $pdo->beginTransaction();

    $checkStmt = $pdo->prepare("
        SELECT EXISTS(
            SELECT 1 FROM thread_reactions WHERE thread_id = ? AND reacted_by = ? AND type = ?
        )
    ");
    $checkStmt->execute([$threadId, $userId, $reactionType]);
    $exists = (bool)$checkStmt->fetchColumn();

    if ($action === 'inspired') {
        if ($exists) {
            $pdo->rollBack();
            send_json(['success' => false, 'message' => 'Already inspired']);
        }

        // Insert reaction
        $insertStmt = $pdo->prepare("
            INSERT INTO thread_reactions (thread_id, reacted_by, type)
            VALUES (?, ?, ?)
        ");
        $insertStmt->execute([$threadId, $userId, $reactionType]);

        // Update count
        $pdo->prepare("
            UPDATE threads
            SET inspired_count = inspired_count + 1
            WHERE thread_id = ?
        ")->execute([$threadId]);

        $response['user_has_inspired'] = true;

        $countStmt = $pdo->prepare("SELECT inspired_count FROM threads WHERE thread_id = ?");
        $countStmt->execute([$threadId]);
        $response['inspired_count'] = (int)$countStmt->fetchColumn();

    } elseif ($action === 'uninspired') {
        if (!$exists) {
            $pdo->rollBack();
            send_json(['success' => false, 'message' => 'Not inspired yet']);
        }

        // Remove reaction
        $deleteStmt = $pdo->prepare("
            DELETE FROM thread_reactions 
            WHERE thread_id = ? AND reacted_by = ? AND type = ?
        ");
        $deleteStmt->execute([$threadId, $userId, $reactionType]);

        // Decrease count
        $pdo->prepare("
            UPDATE threads
            SET inspired_count = GREATEST(0, inspired_count - 1)
            WHERE thread_id = ?
        ")->execute([$threadId]);

        $response['user_has_inspired'] = false;

        $countStmt = $pdo->prepare("SELECT inspired_count FROM threads WHERE thread_id = ?");
        $countStmt->execute([$threadId]);
        $response['inspired_count'] = (int)$countStmt->fetchColumn();
    }

    // --- Commit DB changes ---
    $pdo->commit();

    // --- Send notification (AFTER commit) ---
    if ($action === 'inspired' && $thread['created_by'] != $userId) {
        try {
            error_log(sprintf("[%s] Preparing to insert notification for user=%s by user=%s thread=%s",
                date('Y-m-d H:i:s'),
                $thread['created_by'],
                $userId,
                $threadId
            ));

            $notifStmt = $pdo->prepare("
                INSERT INTO threads_notifications (user_id, type, thread_id, sender_id, message)
                VALUES (?, 'inspired', ?, ?, ?)
            ");
            $notifStmt->execute([
                $thread['created_by'],
                $threadId,
                $userId,
                "Someone was inspired by your thread!"
            ]);

            error_log(sprintf("[%s] Notification inserted successfully", date('Y-m-d H:i:s')));

            if (function_exists('sendFCMNotification')) {
                $data = ['thread_id' => $threadId, 'type' => 'inspired'];
                sendFCMNotification(
                    $pdo,
                    $thread['created_by'],
                    'Inspired Reaction',
                    "Someone was inspired by '{$thread['title']}'",
                    $data
                );
            }
        } catch (Throwable $notifErr) {
            error_log(sprintf("[%s] [Notification Error] %s\n", date('Y-m-d H:i:s'), $notifErr->getMessage()));
        }
    }

    // --- Success Response ---
    send_json([
        'success' => true,
        'message' => $action === 'inspired' ? 'Inspiration added' : 'Inspiration removed',
        ...$response
    ]);

} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    error_log(sprintf(
        "[%s] [Toggle Reaction Error] %s in %s:%d\nTrace:\n%s\n",
        date('Y-m-d H:i:s'),
        $e->getMessage(),
        $e->getFile(),
        $e->getLine(),
        $e->getTraceAsString()
    ));

    send_json(['error' => 'Internal Server Error'], 500);
}
?>
