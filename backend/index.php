<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<title>Opening Ideaship...</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<style>
    body {
        font-family: Arial, sans-serif;
        background: #ffffff;
        text-align: center;
        padding-top: 120px;
        color: #000;
    }
    .logo {
        width: 110px;
        margin-bottom: 20px;
    }
    .msg {
        font-size: 22px;
        font-weight: 500;
    }
    .sub {
        font-size: 14px;
        color: #555;
        margin-top: 8px;
    }
    .btn {
        display: inline-block;
        margin-top: 20px;
        padding: 10px 18px;
        background: #000;
        color: #fff;
        border-radius: 8px;
        text-decoration: none;
        font-size: 16px;
    }
</style>

<script>
    function openApp() {
        // Attempt to open the Ideaship App
        window.location = "awarcrown://open";

        // If app not installed → redirect to Play Store after 2 seconds
        setTimeout(function() {
            window.location = "https://play.google.com/store/apps/details?id=com.awarcrown.ideaship";
        }, 2000);
    }
</script>

</head>
<body onload="openApp()">

    <img class="logo" src="https://awarcrown.com/images/black_logo.png" alt="Ideaship Logo">

    <div class="msg">Opening Ideaship Application...</div>
    <div class="sub">(If the app doesn't open automatically, click below)</div>

    <a class="btn" href="awarcrown://open">Open in App</a>

    <a class="btn" style="background:#4285F4;margin-left:10px;" 
       href="https://play.google.com/store/apps/details?id=com.awarcrown.ideaship">
        Download from Play Store
    </a>

</body>
</html>
