<?php
/**
 * CRON WORKER: Process queued post IDs for hot score updates
 * Runs every few minutes — lightweight & safe
 */

require_once 'config.php'; // includes $pdo connection

$queueFile = __DIR__ . '/hot_score_queue.txt';
$lockFile  = __DIR__ . '/hot_score_worker.lock'; // prevents overlap

// --- 1️⃣ Prevent multiple workers from running simultaneously ---
if (file_exists($lockFile) && (time() - filemtime($lockFile)) < 300) { // 5 min lock
    exit; // another worker is already running
}
file_put_contents($lockFile, time());

// --- 2️⃣ Read and clear the queue file ---
if (!file_exists($queueFile)) {
    unlink($lockFile);
    exit;
}

$lines = file($queueFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
if (empty($lines)) {
    unlink($lockFile);
    exit;
}

// Clear queue (so next run only processes new ones)
file_put_contents($queueFile, "");

// --- 3️⃣ Process unique post IDs ---
$postIds = array_unique(array_map('intval', $lines));
$processedCount = 0;

foreach ($postIds as $post_id) {
    if ($post_id <= 0) continue;

    try {
        // Fetch post details
        $stmt = $pdo->prepare("
            SELECT like_count, share_count, created_at 
            FROM posts 
            WHERE post_id = :post_id
        ");
        $stmt->execute(['post_id' => $post_id]);
        $post = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$post) continue;

        // Get comments count
        $cStmt = $pdo->prepare("SELECT COUNT(*) FROM post_comments WHERE post_id = :pid");
        $cStmt->execute(['pid' => $post_id]);
        $comments = (int)$cStmt->fetchColumn();

        // Calculate hot score
        $likes = (int)$post['like_count'];
        $shares = (int)$post['share_count'];
        $createdAt = new DateTime($post['created_at']);
        $now = new DateTime();
        $hours = max(1, ($createdAt->diff($now)->days * 24) + $createdAt->diff($now)->h);
        $score = ($likes + ($comments * 0.5) + ($shares * 2)) / pow($hours + 2, 1.2);

        // Update post
        $uStmt = $pdo->prepare("UPDATE posts SET hot_score = :s WHERE post_id = :pid");
        $uStmt->execute(['s' => $score, 'pid' => $post_id]);

        $processedCount++;

        // Small delay to avoid DB overload
        usleep(200000); // 0.2 second pause per post

    } catch (Exception $e) {
        error_log("HotScoreWorker error on post $post_id: " . $e->getMessage());
    }
}

// --- 4️⃣ Log results & clean up ---
file_put_contents(__DIR__ . '/hot_score_log.txt', 
    date('Y-m-d H:i:s') . " - Processed $processedCount posts\n", FILE_APPEND
);

unlink($lockFile); // remove lock file after finishing
?>