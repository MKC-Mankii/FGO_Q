<?php
    header("Content-Type:text/html;charset=UTF-8");
    error_reporting(0);

    if (version_compare(phpversion(), '7.1.0', '<')) {
        echo "当前PHP版本过低，请使用PHP7.1及以上版本。<br><br>如果不会搭建环境, 请参考:<a href='https://zimaoxy.com/b/t-2876-1-1.html' target=_blank>关于紫猫插件的共享网络数据NetData系列搭建环境新版教程</a>";
        return;
    }

    if (file_exists("config.php")) {
        echo "已锁定配置<br>如果忘记通信密钥, 请删除同级网站目录下的config.php文件后, 重新打开本网页填写提交配置<br>点击访问<a href='sql.php'>sql.php</a>页面<br><br>如果不会搭建环境, 请参考:<a href='https://zimaoxy.com/b/t-2876-1-1.html' target=_blank>关于紫猫插件的共享网络数据NetData系列搭建环境新版教程</a>";
        return;
    }

    if (isset($_POST["DB_HOST"])) {
        try {
            $servername = $_POST["DB_HOST"];
            $database_name = $_POST["DB_NAME"];
            $username = $_POST["DB_USER"];
            $password = $_POST["DB_PWD"];
            $api_token = $_POST["DB_TOKEN"];
            $conn = new PDO("mysql:host=$servername", $username, $password);
        
            $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

            $sql = "show databases;";
            $res = $conn->query($sql);
            $res = $res->fetchAll(PDO::FETCH_ASSOC);
            $database_list = [];
            foreach($res as $k => $v) {
                $database_list[] = $v['Database'];
            }
            if (!in_array($database_name, $database_list)) {
                $sql = "CREATE DATABASE $database_name";
                $conn->exec($sql);
            }

            $string = '<?php';
            $string .= "\r\ndefine('DB_HOST','$servername');";
            $string .= "\r\ndefine('DB_NAME','$database_name');";
            $string .= "\r\ndefine('DB_USER','$username');";
            $string .= "\r\ndefine('DB_PWD','$password');";
            $string .= "\r\ndefine('DB_TOKEN','$api_token');";

            file_put_contents('config.php',$string);
            echo "初始化配置完成<br>请牢记你的通信密钥是$api_token<br>点击访问<a href='sql.php'>sql.php</a>页面<br><br>如果不会搭建环境, 请参考:<a href='https://zimaoxy.com/b/t-2876-1-1.html' target=_blank>关于紫猫插件的共享网络数据NetData系列搭建环境新版教程</a>";
        }
        catch(PDOException $e)
        {
            echo $sql . "<br>" . $e->getMessage();
        }
        
        $conn = null;
        return;
    }
?>


<form name="configs" action="" method="post">
    数据库地址: <input type="text" name="DB_HOST" value="localhost" /><br />
    数据库名字: <input type="text" name="DB_NAME" value="zimaoxy" /><br />
    数据库账户: <input type="text" name="DB_USER" value="root" /><br />
    数据库密码: <input type="text" name="DB_PWD" value="root" /><br />
    通信密钥: <input type="text" name="DB_TOKEN" value="QQ345911220" /><br />
    <input type="submit" value="安装" />
</form>
<div>
    <p>说明：</p>
    <p>
        数据库地址一般无需修改，localhost代表本地数据库，大部分服务器与数据库是一起的。
    </p>
    <p>
        数据库名字可以根据情况修改，若该数据库不存在时并且账号有创建数据库权限时，提交后会自动创建该数据库。
    </p>
    <p>
        数据库账户可以根据情况修改，访问数据库的账户名。
    </p>
    <p>
        数据库密码可以根据情况修改，访问数据库账户的密码。
    </p>
    <p>
        通信密钥强烈建议修改为长度16位至32位的内容，支持英文和数字。<br>
        插件内部通过此密钥访问sql.php执行代码，请勿对外泄露此秘钥。<br>
    </p>
    <p>
        如果不会搭建环境, 请参考: <a href='https://zimaoxy.com/b/t-2876-1-1.html' target=_blank>关于紫猫插件的共享网络数据NetData系列搭建环境新版教程</a>
    </p>
</div>