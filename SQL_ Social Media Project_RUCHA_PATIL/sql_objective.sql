CREATE DATABASE ig_clone;

USE ig_clone;

-- Q2)What is the distribution of user activity levels (e.g., number of posts, likes, comments) across the user base?
-- i) hoe many photos eeach user has post
SELECT u.id as user_id, u.username , count(p.id) as post_count
FROM users u
LEFT JOIN photos p ON u.id = p.user_id
GROUP BY u.id, u.username;

-- ii)likes given by each user
SELECT u.id as user_id, u.username, count(l.photo_id) as total_likes
FROM users u
LEFT JOIN likes l ON u.id = l.user_id
GROUP BY u.id , u.username;

-- iii) comments made by each user
SELECT u.id as user_id, u.username, count(c.id) as total_comments
FROM users u
LEFT JOIN comments c ON u.id = c.user_id
GROUP BY u.id , u.username;

-- iv) Combined Final Query
SELECT 
    u.id AS user_id, 
    u.username,
    COALESCE(post_counts.post_count, 0) AS post_count,
    COALESCE(like_counts.like_count, 0) AS like_count,
    COALESCE(comment_counts.comment_count, 0) AS comment_count
FROM 
    users u
LEFT JOIN 
    (SELECT user_id, COUNT(id) AS post_count 
     FROM photos 
     GROUP BY user_id) post_counts 
ON u.id = post_counts.user_id
LEFT JOIN 
    (SELECT user_id, COUNT(photo_id) AS like_count 
     FROM likes 
     GROUP BY user_id) like_counts 
ON u.id = like_counts.user_id
LEFT JOIN 
    (SELECT user_id, COUNT(id) AS comment_count 
     FROM comments 
     GROUP BY user_id) comment_counts 
ON u.id = comment_counts.user_id;

-- -----------------------------------------------------------------------------------------------------------------------------

-- Q3) Calculate the average number of tags per post (photo_tags and photos tables).

SELECT round(AVG(tag_count),2) AS average_tags_per_post
FROM (
SELECT p.id AS photo_id, COUNT(pt.tag_id) AS tag_count
FROM photos p
LEFT JOIN photo_tags pt ON p.id = pt.photo_id
GROUP BY p.id
) AS photo_tag_counts;

-- ----------------------------------------------------------------------------------------------------------------------

-- Q4) Identify the top users with the highest engagement rates (likes, comments) on their posts and rank them.
WITH EngagementRate AS (
    SELECT 
        u.id AS user_id, 
        u.username, 
        COALESCE(l.total_likes, 0) AS total_likes, 
        COALESCE(c.total_comments, 0) AS total_comments,
        COALESCE(p.total_posts, 0) AS total_posts,
        (COALESCE(l.total_likes, 0) + COALESCE(c.total_comments, 0)) / COALESCE(p.total_posts, 1) AS engagement_rate
    FROM users u
    LEFT JOIN (
        SELECT user_id, COUNT(photo_id) AS total_likes
        FROM likes
        GROUP BY user_id
    ) l ON u.id = l.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(id) AS total_comments
        FROM comments
        GROUP BY user_id
    ) c ON u.id = c.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(id) AS total_posts
        FROM photos
        GROUP BY user_id
    ) p ON u.id = p.user_id
)
SELECT 
    user_id, 
    username, 
    total_likes, 
    total_comments, 
    total_posts,
    ROUND(engagement_rate, 2) AS engagement_rate, 
    RANK() OVER (ORDER BY engagement_rate DESC) AS engagement_rank 
FROM EngagementRate
GROUP BY user_id
HAVING total_posts >0
ORDER BY engagement_rank
limit 10;


-- ----------------------------------------------------------------------------------------------------------------------------

-- Q5) Which users have the highest number of followers and followings?
-- i)users with the maximum number of followers:
SELECT
    followee_id,
    COUNT(follower_id) AS follower_count
FROM follows
GROUP BY followee_id
ORDER BY follower_count DESC;

-- ii)who follow the maximum number of other users
SELECT
    follower_id,
    COUNT(followee_id) AS following_count
FROM follows
GROUP BY follower_id
ORDER BY following_count DESC;

-- ----------------------------------------------------------------------------------------------------------------------------

-- Q6) Calculate the average engagement rate (likes, comments) per post for each user.
SELECT 
    u.id as user_id,
    u.username,
    COALESCE(p.num_posts, 0) AS Total_Post,
    COALESCE(l.num_likes, 0) AS Total_likes,
    COALESCE(c.num_comments, 0) AS Total_comments,
    CASE 
        WHEN COALESCE(p.num_posts, 0) = 0 THEN 0
        ELSE (COALESCE(l.num_likes, 0) + COALESCE(c.num_comments, 0)) / COALESCE(p.num_posts, 0)
    END AS avg_engagement_rate
FROM users u
LEFT JOIN 
    (SELECT user_id, COUNT(*) AS num_posts
     FROM photos
     GROUP BY user_id) p ON u.id = p.user_id
LEFT JOIN 
    (SELECT user_id, COUNT(*) AS num_likes
     FROM likes
     GROUP BY user_id) l ON u.id = l.user_id
LEFT JOIN 
    (SELECT user_id, COUNT(*) AS num_comments
     FROM comments
     GROUP BY user_id) c ON u.id = c.user_id
	ORDER BY avg_engagement_rate DESC;
 
-- ----------------------------------------------------------------------------------------------------------------------------

-- Q7) Get the list of users who have never liked any post (users and likes tables)
SELECT id as user_id , username
FROM users 
where id not in(
 select user_id from likes);
 
-- ---------------------------------------------------------------------------------------------------------------------------
 
-- For Q8 and Q9 refer to the doc file as it contains only approach part 
 
-- ----------------------------------------------------------------------------------------------------------------------------
 
-- Q10)Calculate the total number of likes, comments, and photo tags for each user.
    
    WITH LikesCount AS (
    SELECT user_id, COUNT(*) AS total_likes 
    FROM likes 
    GROUP BY user_id
),
CommentsCount AS (
    SELECT user_id, COUNT(*) AS total_comments 
    FROM comments 
    GROUP BY user_id
),
PhotoTagsCount AS (
    SELECT tag_id, COUNT(*) AS total_photo_tags 
    FROM photo_tags 
    GROUP BY tag_id
)
SELECT 
    u.id as id,
    u.username,
    COALESCE(lc.total_likes, 0) AS total_likes,
    COALESCE(cc.total_comments, 0) AS total_comments,
    COALESCE(ptc.total_photo_tags, 0) AS total_photo_tags
FROM users u
LEFT JOIN LikesCount lc ON u.id = lc.user_id
LEFT JOIN CommentsCount cc ON u.id = cc.user_id
LEFT JOIN PhotoTagsCount ptc ON u.id = ptc.tag_id;


-- ----------------------------------------------------------------------------------------------------------------------------
    
-- Q11)Rank users based on their total engagement (likes, comments, shares) over a month. 
WITH MonthlyEngagement AS (
    SELECT u.id AS user_id, 
		   u.username, 
           COALESCE(l.total_likes, 0) AS total_likes, 
           COALESCE(c.total_comments, 0) AS total_comments,
		   (COALESCE(l.total_likes, 0) + COALESCE(c.total_comments, 0)) AS total_engagement
    FROM users u
    LEFT JOIN (
        SELECT user_id, COUNT(photo_id) AS total_likes
        FROM likes
        WHERE DATE(created_at) >= '2024-07-01' OR DATE(created_at) <= '2024-07-31'
        GROUP BY user_id
    ) l ON u.id = l.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(id) AS total_comments
        FROM comments
        WHERE DATE(created_at) >= '2024-07-01' OR DATE(created_at) <= '2024-07-31'
        GROUP BY user_id
    ) c ON u.id = c.user_id
)
SELECT user_id, username, total_likes, total_comments, total_engagement,
RANK() OVER (ORDER BY total_engagement DESC) AS engagement_rank
FROM MonthlyEngagement
ORDER BY engagement_rank;

-- --------------------------------------------------------------------------------------------------------------------------

-- Q12 Retrieve the hashtags that have been used in posts with the highest average number of likes. 
-- Use a CTE to calculate the average likes for each hashtag first. 
WITH HashtagLikes AS (
    SELECT ht.tag_name, COUNT(l.photo_id) AS total_likes, COUNT(DISTINCT p.id) AS total_posts
    FROM tags ht
    JOIN photo_tags pt ON ht.id = pt.tag_id
    JOIN photos p ON pt.photo_id = p.id
    LEFT JOIN likes l ON p.id = l.photo_id
    GROUP BY ht.tag_name
),
AverageLikesPerHashtag AS (
    SELECT tag_name, ROUND((CAST(total_likes AS FLOAT) / total_posts),2) AS avg_likes
    FROM HashtagLikes
)
SELECT tag_name, avg_likes
FROM AverageLikesPerHashtag
group by tag_name
having avg_likes >= 34.5
ORDER BY avg_likes DESC
;
-- -------------------------------------------------------------------------------------------------------------------

-- Q13) Retrieve the users who have started following someone after being followed by that person 
WITH FollowRelationships AS (
    SELECT
        f1.follower_id AS user_id_1,
        f1.followee_id AS user_id_2,
        f1.created_at AS followee_follow_date,
        f2.created_at AS follower_follow_date
    FROM follows f1
    JOIN follows f2 ON f1.followee_id = f2.follower_id
    WHERE f1.follower_id <> f2.followee_id
)
SELECT
    user_id_1,
    user_id_2,
    followee_follow_date,
    follower_follow_date
FROM FollowRelationships
WHERE follower_follow_date > followee_follow_date
ORDER BY user_id_1, user_id_2;




