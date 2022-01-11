<?php

header("Content-Type:text/html;charset=UTF-8");
error_reporting(0);

require_once 'medoo.php';
if (!file_exists("config.php")){
	echo "<a href='install.php' target='_blank'>点我进入安装页面</a> 提交正确配置后, 再重新访问本页面<br><br>如果不会搭建环境, 请参考:<a href='https://zimaoxy.com/b/t-2876-1-1.html' target=_blank>关于紫猫插件的共享网络数据NetData系列搭建环境新版教程</a>";
	return;
}

include 'config.php';
if (DB_TOKEN == "") {
	echo "通信密钥设置不能为空, 请删除config.php文件重新提交配置<br><br>如果不会搭建环境, 请参考:<a href='https://zimaoxy.com/b/t-2876-1-1.html' target=_blank>关于紫猫插件的共享网络数据NetData系列搭建环境新版教程</a>";
	return;
}
// Using Medoo namespace
use Medoo\Medoo;

try
{
	$database = new Medoo([
		//数据库类型
		'database_type' => 'mysql',
		//数据库地址
		'server' => DB_HOST,
		//数据库名
		'database_name' => DB_NAME,
		//数据库账户
		'username' => DB_USER,
		//数据库密码
		'password' => DB_PWD,
	
		// [optional]
		'charset' => 'utf8',
		'port' => 3306,
	
		// [optional] Table prefix
		'prefix' => "",
	
		// [optional] Enable logging (Logging is disabled by default for better performance)
		'logging' => false,
	
		// [optional] MySQL socket (shouldn't be used with server and port)
		'socket' => '/tmp/mysql.sock',
	
		// [optional] driver_option for connection, read more from http://www.php.net/manual/en/pdo.setattribute.php
		'option' => [
			PDO::ATTR_CASE => PDO::CASE_NATURAL,
			PDO::ATTR_PERSISTENT => true
		],
	
		// [optional] Medoo will execute those commands after connected to the database for initialization
		'command' => [
			'SET SQL_MODE=ANSI_QUOTES',
		]
	]);
}
catch(Exception $e)
{
	echo "访问数据库失败, 请检查网络或配置是否正确, 若配置错误, 请删除config.php文件后重新操作<br><br>如果不会搭建环境, 请参考:<a href='https://zimaoxy.com/b/t-2876-1-1.html' target=_blank>关于紫猫插件的共享网络数据NetData系列搭建环境新版教程</a>";
	return;
}

if (isset($_POST["action"]) && isset($_POST["token"])) {
	if ($_POST["token"] != DB_TOKEN) {
		echo "密钥错误";
		return;
	}

	switch ($_POST["action"]) {
		case 'init':
			//echo "初始化共享数据:" . $table;
			$table = $_POST["table"];
			$isdel = $_POST["isdel"];
			if ($isdel=="true") {
				$database->drop($table);
			}
			$database->create($table, [
				"id" => [
					"INT",
					"NOT NULL",
					"AUTO_INCREMENT",
					"PRIMARY KEY"
				],
				"`key`" => [
					"VARCHAR(200)",
					"COLLATE utf8mb4_bin",
					"NOT NULL"
				],
				"value" => [
					"LONGTEXT",
					"COLLATE utf8mb4_bin",
					"NOT NULL"
				],
				"type" => [
					"VARCHAR(10)",
					"COLLATE utf8mb4_bin",
					"NOT NULL"
				],
				"KEY `key` (`key`)"
			], [
				"ENGINE" => "MyISAM",
				"AUTO_INCREMENT" => 1,
				"CHARSET" => "utf8mb4",
				"COLLATE" => "utf8mb4_bin"
			]);

			break;
		case 'set':
			// echo "设置数据" . $table . "<br>";
			$table = $_POST["table"];
			$key = $_POST["key"];
			$value = $_POST["value"];
			$type = $_POST["type"];
			if ($database->has($table,[
				"key" => $key
			])) {
				$ret = $database->update($table, [
					"value"=>$value,
					"type"=>$type
				], [
					"key"=>$key
				]);
			} else {
				$ret = $database->insert($table, [
					"key"=>$key,
					"value"=>$value,
					"type"=>$type
				]);
			}
			echo $ret->rowCount();
			break;
		case 'get':
			//获取数据
			$table = $_POST["table"];
			$key = $_POST["key"];
			$isdel = $_POST["isdel"];
			$ret = $database->get($table, [
				"value",
				"type"
			], [
				"key" => $key
			]);
			if ($isdel=="true") {
				$database->delete($table, [
					"key" => $key
				]);
			}
			echo json_encode($ret, JSON_UNESCAPED_UNICODE);
			break;
		case 'del':
			// echo "删除" . $key;
			$table = $_POST["table"];
			$key = $_POST["key"];
			$ret = $database->delete($table, [
				"key" => $key
			]);
			echo $ret->rowCount();
			break;
		case 'getrows':
			//获取多行数据
			$table = $_POST["table"];
			$isdel = $_POST["isdel"];
			$startrow = $_POST["startrow"];
			$rows = $_POST["rows"];
			$ret = $database->select($table, "*", [
				"LIMIT" => [
					$startrow,
					$rows
				],
				"ORDER" => ["id"=>"ASC"]
			]);
			$ids = [];
			foreach ($ret as $key => $value) {
				$ids[] = $value["id"];
			}
			if ($isdel=="true") {
				$database->delete($table, [
					"id" => $ids
				]);
			}
			echo json_encode($ret, JSON_UNESCAPED_UNICODE);
			break;
		case 'count':
			$table = $_POST["table"];
			$ret = $database->count($table);
			echo $ret;
			break;
		case 'query':
			//执行sql代码
			$query = $_POST["query"];
			$ret = $database->query($query)->fetchAll();
			echo json_encode($ret, JSON_UNESCAPED_UNICODE);
			break;
		default:
			echo "错误:未知操作";
			break;
	}
	return;
}


function test_input($data)
{
    $data = trim($data);
    $data = stripslashes($data);
    $data = htmlspecialchars($data);
    return $data;
}

?>
<div>
	<p>
		恭喜通信成功, 本功能用法请查阅<a href="https://zimaoxy.com/m/">文档</a>或者联系QQ <a href="https://zimaoxy.com/addqq.html">345911220</a> 报名紫猫学院课程学习
	</p>
	<p>
		如果忘记通信密钥, 请删除同级网站目录下的config.php文件后, 重新打开 <a href="install.php">安装页面</a> 填写提交配置
	</p>
</div>