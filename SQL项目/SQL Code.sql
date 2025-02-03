Part1《数据预处理》

-- 去重
alter table userbehavior_sample MODIFY id INT PRIMARY KEY auto_increment;
DELETE userbehavior_sample from 
userbehavior_sample,
(
SELECT user_id, item_id, timestamps, MIN(id) id from userbehavior_sample
GROUP BY user_id, item_id, timestamps
HAVING count(*)>1
) as t2
WHERE userbehavior_sample.user_id=t2.user_id
and userbehavior_sample.item_id=t2.item_id
and userbehavior_sample.timestamps=t2.timestamps
and userbehavior_sample.id=t2.id

-- 新增日期：date time hour
-- 更改buffer值
show VARIABLES like '%_buffer%'
set global innodb_buffer_pool_size=10000000000
-- datetime
ALTER table userbehavior_sample add datetimes TIMESTAMP(0);
update userbehavior_sample set datetimes=FROM_UNIXTIME(timestamps);
-- date
ALTER table userbehavior_sample add dates char(10);
ALTER table userbehavior_sample add times char(8);
ALTER table userbehavior_sample add hours char(8);
update userbehavior_sample set dates=SUBSTRING(datetimes,1,10);
update userbehavior_sample set times=SUBSTRING(datetimes,12,8);
update userbehavior_sample set hours=SUBSTRING(datetimes,12,2);
SELECT * from userbehavior_sample limit 5

-- 去异常
SELECT MAX(datetimes), MIN(datetimes) from userbehavior_sample;
DELETE from userbehavior_sample
WHERE datetimes<'2017-11-25 00:00:00'
or datetimes>'2017-12-03 23:59:59'
DELETE from userbehavior_sample WHERE dates is NULL

-- 数据概览
SELECT COUNT(1) from userbehavior_sample


Part2 数据分析

SELECT * FROM `userbehavior_sample`

-- 创建临时表
create table temp_behavior like userbehavior_sample
-- 截取数据
INSERT INTO temp_behavior
SELECT * from userbehavior_sample limit 100000;
-- 测试
SELECT * from temp_behavior;

-- 获客情况
-- 页面浏览量（pv）
SELECT dates, count('pv') as pv from temp_behavior
where behavior_type='pv'
GROUP BY dates
ORDER BY dates;
-- 独立访客数
SELECT dates, count(DISTINCT user_id) as unique_user from temp_behavior
where behavior_type='pv'
GROUP BY dates
ORDER BY dates;
-- 合并
SELECT dates, count('pv') as pv, count(DISTINCT user_id) as unique_user, ROUND(count('pv')/count(DISTINCT user_id),1)  as 'pv/uv' from temp_behavior
where behavior_type='pv'
GROUP BY dates
ORDER BY dates;

-- 处理真实数据
CREATE table pv_uv_puv (
dates char(10),
pv int(9),
uv int(9),
puv DECIMAL(10,1)
);

INSERT into pv_uv_puv
SELECT dates, count('pv') as pv, count(DISTINCT user_id) as unique_user, ROUND(count('pv')/count(DISTINCT user_id),1)  as 'pv/uv' from us
where behavior_type='pv'
GROUP BY dates
ORDER BY dates;

SELECT * from pv_uv_puv
DELETE from pv_uv_puv WHERE dates is NULL

SELECT * FROM userbehavior_sample limit 5

-- 计算DAU、MAU
CREATE TABLE DAU(
dates char(10),
DAU int(6)
);
INSERT INTO DAU
SELECT dates, COUNT(DISTINCT user_id) AS DAU
FROM userbehavior_sample
WHERE behavior_type = 'pv'
GROUP BY dates;

SELECT COUNT(DISTINCT user_id) AS user_count
FROM userbehavior_sample
WHERE behavior_type = 'pv'
  AND dates BETWEEN '2017-11-25' AND '2017-12-03';


-- 留存数（自关联）
SELECT 
    a.dates, 
    COUNT(IF(DATEDIFF(b.dates, a.dates) = 0, b.user_id, NULL)) AS retention_0,
    COUNT(IF(DATEDIFF(b.dates, a.dates) = 1, b.user_id, NULL)) AS retention_1,
    COUNT(IF(DATEDIFF(b.dates, a.dates) = 7, b.user_id, NULL)) AS retention_7
FROM
    (SELECT user_id, dates 
     FROM userbehavior_sample
     GROUP BY user_id, dates
    ) a
JOIN
    (SELECT user_id, dates 
     FROM userbehavior_sample
     GROUP BY user_id, dates
    ) b ON a.user_id = b.user_id AND a.dates <= b.dates
GROUP BY a.dates;

-- 留存率
SELECT 
    a.dates, 
    COUNT(IF(DATEDIFF(b.dates, a.dates) = 1, b.user_id, NULL))/COUNT(IF(DATEDIFF(b.dates, a.dates) = 0, b.user_id, NULL)) AS retention_rate_1,
    COUNT(IF(DATEDIFF(b.dates, a.dates) = 7, b.user_id, NULL)) /COUNT(IF(DATEDIFF(b.dates, a.dates) = 0, b.user_id, NULL)) AS retention_rate_7
FROM
    (SELECT user_id, dates 
     FROM userbehavior_sample
     GROUP BY user_id, dates
    ) a
JOIN
    (SELECT user_id, dates 
     FROM userbehavior_sample
     GROUP BY user_id, dates
    ) b ON a.user_id = b.user_id AND a.dates <= b.dates
GROUP BY a.dates
order by a.dates;

-- 时间序列（周内&日内行为分析）
SELECT 
    dates, 
    hours,
    COUNT(IF(behavior_type = 'pv', behavior_type, NULL)) AS pv,
    COUNT(IF(behavior_type = 'cart', behavior_type, NULL)) AS cart,
    COUNT(IF(behavior_type = 'fav', behavior_type, NULL)) AS fav,
    COUNT(IF(behavior_type = 'buy', behavior_type, NULL)) AS buy
FROM 
    userbehavior_sample
GROUP BY 
    dates, 
    hours
ORDER BY 
    dates, 
    hours;

-- 创建表
CREATE TABLE date_hour_behavior (
    dates CHAR(10),
    hours CHAR(2),
    pv INT,
    cart INT,
    fav INT,
    buy INT
); 

INSERT INTO date_hour_behavior
SELECT 
    dates, 
    hours,
    COUNT(IF(behavior_type = 'pv', behavior_type, NULL)) AS pv,
    COUNT(IF(behavior_type = 'cart', behavior_type, NULL)) AS cart,
    COUNT(IF(behavior_type = 'fav', behavior_type, NULL)) AS fav,
    COUNT(IF(behavior_type = 'buy', behavior_type, NULL)) AS buy
FROM 
    userbehavior_sample
GROUP BY 
    dates, 
    hours
ORDER BY 
    dates, 
    hours;
                
-- 统计各类行为用户数
SELECT behavior_type,
COUNT(DISTINCT user_id) user_number
from userbehavior_sample
GROUP BY behavior_type
ORDER BY behavior_type DESC

-- 创建表
CREATE TABLE behavior_number(
behavior_type VARCHAR(5),
user_number int);

INSERT INTO behavior_number
SELECT behavior_type,
COUNT(DISTINCT user_id) user_number
from userbehavior_sample
GROUP BY behavior_type
ORDER BY behavior_type DESC

-- 统计各类行为数
CREATE TABLE behavior_number_0(
behavior_type VARCHAR(5),
user_number int);

INSERT INTO behavior_number_0
SELECT behavior_type,
COUNT(*) user_number
from userbehavior_sample
GROUP BY behavior_type
ORDER BY behavior_type DESC

SELECT (28586+55248)/895308 --收藏和加购转化率
SELECT 20317/895308 --购买转化率 

-- 用户行为路径分析
CREATE VIEW user_behavior_view AS
SELECT user_id, item_id,
COUNT(if(behavior_type='pv',behavior_type,NULL)) pv,
COUNT(if(behavior_type='fav',behavior_type,NULL))fav,
COUNT(if(behavior_type='cart',behavior_type,NULL)) cart,
COUNT(if(behavior_type='buy',behavior_type,NULL))buy
FROM userbehavior_sample
GROUP BY user_id, item_id;

-- 用户行为标准化
CREATE VIEW user_behavior_standard AS
SELECT user_id, item_id, 
(CASE WHEN pv>0 THEN 1 ELSE 0 END ) '已浏览',
(CASE WHEN fav>0 THEN 1 ELSE 0 END ) '已收藏',
(CASE WHEN cart>0 THEN 1 ELSE 0 END ) '已加购',
(CASE WHEN buy>0 THEN 1 ELSE 0 END ) '已购买'
FROM user_behavior_view;

-- 路径类型
CREATE VIEW user_behavior_path AS
SELECT *, CONCAT(已浏览, 已收藏, 已加购, 已购买) '购买路径类型'
from user_behavior_standard as a
where a.已购买>0


-- 统计各类购买行为数量
CREATE VIEW path_count AS
SELECT 购买路径类型, count(*) 数量 from user_behavior_path 
GROUP BY 购买路径类型
order by 数量
SELECT * from path_count


CREATE table description(
path_type char(4),
description VARCHAR(40));

INSERT into description
VALUES('0001','直接购买'),
('1001','浏览后购买'),
('0011','加购后购买'),
('1011','浏览加购后购买'),
('0101','收藏后购买'),
('1101','浏览收藏后购买'),
('0111','收藏加购后购买'),
('1111','浏览收藏加购后购买')


-- 合并standard和description
CREATE TABLE user_behavior_standard_table
AS
SELECT *, CONCAT(已浏览, 已收藏, 已加购, 已购买) '购买路径类型' FROM user_behavior_standard;
SELECT * from  user_behavior_standard_table LIMIT 5


CREATE TABLE user_behavior_combined_standard (
    user_id INT,
    item_id INT,
    `已浏览` INT,
    `已收藏` INT,
    `已加购` INT,
    `已购买` INT,
    `购买路径类型` VARCHAR(10),
    description VARCHAR(40)
);
INSERT INTO user_behavior_combined_standard (user_id, item_id, `已浏览`, `已收藏`, `已加购`, `已购买`, `购买路径类型`, description)
SELECT 
    a.user_id,
    a.item_id,
    a.`已浏览`,
    a.`已收藏`,
    a.`已加购`,
    a.`已购买`,
    a.`购买路径类型`,
    d.description
FROM 
    user_behavior_standard_table a
LEFT JOIN 
    description d ON a.`购买路径类型` = d.path_type;

UPDATE user_behavior_combined_standard
SET description = '未购买'
WHERE description IS NULL;


SELECT * from path_count p
JOIN description d
on p.购买路径类型=d.path_type
ORDER BY 数量 desc

drop VIEW user_behavior_view;
drop VIEW user_behavior_standard;
drop VIEW user_behavior_path;
drop VIEW path_count;

-- 创建表
CREATE table path_result(
path_type char(4),
description varchar(40),
num int);

CREATE VIEW user_behavior_view AS
SELECT user_id, item_id,
COUNT(if(behavior_type='pv',behavior_type,NULL)) pv,
COUNT(if(behavior_type='fav',behavior_type,NULL))fav,
COUNT(if(behavior_type='cart',behavior_type,NULL)) cart,
COUNT(if(behavior_type='buy',behavior_type,NULL))buy
FROM userbehavior_sample
GROUP BY user_id, item_id;

-- 用户行为标准化
CREATE VIEW user_behavior_standard AS
SELECT user_id, item_id, 
(CASE WHEN pv>0 THEN 1 ELSE 0 END ) '已浏览',
(CASE WHEN fav>0 THEN 1 ELSE 0 END ) '已收藏',
(CASE WHEN cart>0 THEN 1 ELSE 0 END ) '已加购',
(CASE WHEN buy>0 THEN 1 ELSE 0 END ) '已购买'
FROM user_behavior_view;

-- 路径类型
CREATE VIEW user_behavior_path AS
SELECT *, CONCAT(已浏览, 已收藏, 已加购, 已购买) '购买路径类型'
from user_behavior_standard as a
where a.已购买>0

-- 统计各类购买行为数量
CREATE VIEW path_count AS
SELECT 购买路径类型, count(*) 数量 from user_behavior_path 
GROUP BY 购买路径类型
order by 数量


INSERT into path_result
SELECT path_type,description,数量 from path_count p
JOIN description d
on p.购买路径类型=d.path_type
ORDER BY 数量 desc

SELECT * from path_result

-- MTU
CREATE TABLE daily_ordering_users (dates DATE, daily_ordering_users_count INT);
INSERT INTO daily_ordering_users (dates, daily_ordering_users_count)
SELECT dates, COUNT(DISTINCT user_id) 
FROM userbehavior_sample
WHERE behavior_type = 'buy'
GROUP BY dates
ORDER BY dates;

-- 每人每天购买频次
CREATE TABLE daily_avg_purchase_frequency_simplified (dates DATE, daily_avg_frequency DECIMAL(10, 2));
INSERT INTO daily_avg_purchase_frequency_simplified (dates, daily_avg_frequency)
SELECT dates, ROUND(AVG(user_purchase_count), 2)
FROM (
    SELECT dates, user_id, COUNT(*) AS user_purchase_count
    FROM userbehavior_sample
    WHERE behavior_type = 'buy'
    GROUP BY dates, user_id
) AS subquery
GROUP BY dates
ORDER BY dates;

-- 热门品类
SELECT category_id,
count(if(behavior_type='pv', behavior_type, null) )'品类浏览量'
from userbehavior_sample
group by category_id
ORDER BY 2 DESC
limit 5

-- 热门商品
SELECT item_id,
count(if(behavior_type='pv', behavior_type, null) )'商品浏览量'
from userbehavior_sample
group by item_id
ORDER BY 2 DESC
limit 5

--热门品类中的热门商品
SELECT category_id,item_id,品类商品浏览量 from(
SELECT category_id,item_id,
count(if(behavior_type='pv', behavior_type, null) )'品类商品浏览量', rank()over(PARTITION by category_id ORDER BY '品类商品浏览量' DESC) r
from userbehavior_sample
group by category_id,item_id
ORDER BY 3 DESC) a
where r=1
order by a.品类商品浏览量 DESC
limit 10

-- 创建表存储
CREATE TABLE popular_categroies(
category_id int,
品类浏览量 int);
INSERT into popular_categroies
SELECT category_id,
count(if(behavior_type='pv', behavior_type, null) )'品类浏览量'
from userbehavior_sample
group by category_id
ORDER BY 2 DESC
limit 5

CREATE TABLE popular_item(
item_id int,
商品浏览量 int);
INSERT INTO popular_item
SELECT item_id,
count(if(behavior_type='pv', behavior_type, null) )'商品浏览量'
from userbehavior_sample
group by item_id
ORDER BY 2 DESC
limit 5

CREATE TABLE popular_category_item(
category_id int,
item_id int,
品类商品浏览量 int);
INSERT into popular_category_item
SELECT category_id,item_id,品类商品浏览量 from(
SELECT category_id,item_id,
count(if(behavior_type='pv', behavior_type, null) )'品类商品浏览量', rank()over(PARTITION by category_id ORDER BY '品类商品浏览量' DESC) r
from userbehavior_sample
group by category_id,item_id
ORDER BY 3 DESC) a
where r=1
order by a.品类商品浏览量 DESC
limit 10


CREATE TABLE popular_sale_item (
    item_id INT,
    sales_volume INT
);
INSERT INTO popular_sale_item (item_id, sales_volume)
SELECT 
    item_id,
    COUNT(IF(behavior_type = 'buy', behavior_type, NULL)) AS sales_volume
FROM 
    userbehavior_sample
GROUP BY 
    item_id
ORDER BY 2 DESC
limit 20;


-- 商品转化率
CREATE TABLE        item_detail(
item_id int,
pv int,
fav int,
cart int,
buy int,
item_transction_rate float);

INSERT into item_detail
SELECT 
    item_id,
    COUNT(IF(behavior_type = 'pv', behavior_type, NULL)) AS pv,
    COUNT(IF(behavior_type = 'fav', behavior_type, NULL)) AS fav,
    COUNT(IF(behavior_type = 'cart', behavior_type, NULL)) AS cart,
    COUNT(IF(behavior_type = 'buy', behavior_type, NULL)) AS buy,
    COUNT(DISTINCT IF(behavior_type = 'buy', user_id, NULL)) / COUNT(DISTINCT user_id) AS 商品转化率
FROM 
    userbehavior_sample
GROUP BY 
    item_id
ORDER BY 
    商品转化率 DESC;