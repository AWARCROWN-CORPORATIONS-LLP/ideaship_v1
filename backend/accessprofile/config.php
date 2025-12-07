<?php
// Database Configuration
$host = 'localhost';
$dbname = 'app_auth';
$username = 'awarcrownadmins';
$password = 'Awarcrown@0523';

try {
    // Create a new PDO instance
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8", $username, $password);
    
    // Set PDO error mode to exception
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
   
} catch (PDOException $e) {
    // Catch any errors
    die("Database connection failed: " . $e->getMessage());
}
?>
