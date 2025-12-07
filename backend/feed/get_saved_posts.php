<?php
header("Content-Type: application/json; charset=UTF-8");
require_once "config.php";

// ----------------------------
// Utility Response Function
// ----------------------------
function response($data, $code = 200) {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

// ----------------------------
// Decrypt Function (SAME AS FEED)
// ----------------------------
function decryptData($data)
{
    try {
        if (!$data) return null;
        $decoded = base64_decode($data);
        if ($decoded === false || strpos($decoded, "::") === false) return null;

        list($enc, $iv) = explode("::", $decoded, 2);
        return openssl_decrypt(
            $enc,
            "AES-256-CBC",
            base64_decode("7/bUxXBcXrgqyASvQSbLSKNce+rvWJt0botpIrA4poQ="),
            0,
            $iv
        );
    } catch (Exception $e) {
        return null;
    }
}

// ----------------------------
// Inputs
// ----------------------------
$post_id = $_GET['post_id'] ?? null;
$username = $_GET['username'] ?? '';

if (!$post_id) {
    response(["error" => "post_id is required"], 400);
}

// ----------------------------
// Resolve Viewer ID
// ----------------------------
$viewer_id = 0;
if ($username !== '') {
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $stmt->execute([$username]);
    $u = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($u) $viewer_id = $u['id'];
}

// ----------------------------
// Fetch Post
// ----------------------------
$sql = "
    SELECT 
        p.id AS post_id,
        p.user_id,
        p.content,
        p.media_path AS media_url,
        p.created_at,

        u.username,
        u.profile_picture,

        (SELECT COUNT(*) FROM post_likes WHERE post_id = p.id) AS like_count,
        (SELECT COUNT(*) FROM post_comments WHERE post_id = p.id) AS comment_count,
        (SELECT COUNT(*) FROM post_likes WHERE post_id = p.id AND user_id = :viewer_id) AS is_liked
    FROM posts p
    JOIN users u ON u.id = p.user_id
    WHERE p.id = :post_id
    LIMIT 1
";

$stmt = $pdo->prepare($sql);
$stmt->execute([
    ':post_id' => $post_id,
    ':viewer_id' => $viewer_id
]);

$post = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$post) {
    response(["error" => "Post not found"], 404);
}

// ----------------------------
// DECRYPT MEDIA URL (FIXED)
// ----------------------------
if (!empty($post["media_url"])) {

    $dec = decryptData($post["media_url"]);

    if ($dec) {
        $fullPath = $_SERVER['DOCUMENT_ROOT'] . "/feed/" . $dec;

        if (file_exists($fullPath)) {
            $post["media_url"] = "/feed/" . $dec;
        } else {
            $post["media_url"] = "/feed/Posts/default-image.png";
        }

    } else {
        $post["media_url"] = "/feed/Posts/default-image.png";
    }

} else {
    $post["media_url"] = "/feed/Posts/default-image.png";
}

// ----------------------------
// Profile picture fix
// ----------------------------
if (!empty($post["profile_picture"])) {
    $post["profile_picture"] = $post["profile_picture"]; 
}

// ----------------------------
// Boolean fix
// ----------------------------
$post["is_liked"] = $post["is_liked"] > 0 ? 1 : 0;

// ----------------------------
// Success Response
// ----------------------------
response([
    "success" => true,
    "post" => $post
]);
?>
