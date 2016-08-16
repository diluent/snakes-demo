{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE PatternGuards #-}
module Snakes.Model.Snake where

import Graphics.Gloss.Data.Color
import Graphics.Gloss.Data.Point
import Graphics.Gloss.Data.Vector
import Snakes.Config

-- | A snake is represented by a list of 'Link's and a direction of snake's head.
data Snake = Snake
  { snakeLinks  :: [Link]       -- ^ A list of links. First link is head, last link is tail.
  , snakeDir    :: Vector       -- ^ Snake's direction is a normalized vector.
  , snakeTarget :: Maybe Point  -- ^ Snake's target position.
  , snakeColor  :: Color        -- ^ Color of the snake.
  }

-- | A single link of a 'Snake'.
type Link = Point

-- | A dead snake's link, slowly fading away.
data DeadLink = DeadLink
  { linkLocation  :: Point    -- ^ Current location of the link.
  , linkTimeout   :: Float    -- ^ Time until complete fade out.
  , linkDir       :: Vector   -- ^ Direction of flow.
  }

-- | Create a 'Snake' in the initial location.
initSnake :: (Point, Vector) -> Color -> Snake
initSnake (loc, dir) c = mkSnake loc dir c snakeStartLen snakeLinkGap

-- | @mkSnake n dir dist@ creates a straight 'Snake' with @n@ links,
-- poiting in @dir@ direction and with head at @(0, 0)@.
-- Initial length distance is @dist@.
mkSnake :: Point -> Vector -> Color -> Int -> Float -> Snake
mkSnake loc dir c n dist = Snake
  { snakeLinks  = take n (iterate (subtract step) loc)
  , snakeDir    = d
  , snakeTarget = Nothing
  , snakeColor  = c }
  where
    step = mulSV dist d
    d = normalizeV dir

-- | Feed a snake effectively making it one link longer.
feedSnake :: Snake -> Snake
feedSnake snake@Snake{..} = snake
  { snakeLinks = snakeLinks ++ [ last snakeLinks ] }

-- | Destroy a 'Snake', leaving some floating dead links.
destroySnake :: Snake -> [DeadLink]
destroySnake Snake{..} = zipWith mkDeadLink snakeLinks dirs
  where
    h = head snakeLinks + snakeDir
    t = last snakeLinks - snakeDir
    ls = h : snakeLinks ++ [t]
    dirs = zipWith3 findDir ls snakeLinks (drop 2 ls)
    findDir prev curr next = normalizeV ((curr - prev) + (curr - next))

    mkDeadLink loc dir = DeadLink
      { linkLocation = loc
      , linkTimeout  = deadLinkDuration
      , linkDir      = dir }

-- | Move 'DeadLink' around and update its timer.
updateDeadLink :: Float -> DeadLink -> Maybe DeadLink
updateDeadLink dt link@DeadLink{..}
  | linkTimeout <= dt = Nothing
  | otherwise         = Just link
      { linkLocation = linkLocation + mulSV (dt * deadLinkSpeed) linkDir
      , linkTimeout  = linkTimeout - dt }

-- | Move snake naturally given time delta.
moveSnake :: Float -> Snake -> Snake
moveSnake dt snake@Snake{..} = snake
  { snakeLinks = newLinks
  , snakeDir = newDir }
  where
    newLinks = moveLinks (mulSV (dt * snakeSpeed) newDir) snakeLinks
    newDir = adjustDir dt snake

-- | Adjust snake's direction to follow its target.
adjustDir :: Float -> Snake -> Vector
adjustDir dt snake@Snake{..} =
  case snakeTarget of
    Nothing     -> snakeDir
    Just target ->
      let
        targetDir   = target - head snakeLinks
        targetAngle = angleVV snakeDir targetDir
        angle       = min (abs targetAngle) (dt * snakeTurnRate)
        newDir      = rotateV (angle * angleDir snakeDir targetDir) snakeDir
      in newDir

-- | Move head link by a given vector and then move other links.
moveLinks :: Vector -> [Link] -> [Link]
moveLinks _ [] = []
moveLinks dir (l:ls) = moveLinks' (l + dir) ls
  where
    moveLinks' pos [] = [pos]
    moveLinks' pos (n:ns) = pos : moveLinks' (moveLinkTo pos n) ns

-- | Move a single link closer to a given point.
-- Leave link be if already close enough.
moveLinkTo :: Point -> Link -> Link
moveLinkTo pos link
  | magV (pos - link) < snakeLinkGap = link
  | otherwise = pos - mulSV snakeLinkGap (normalizeV (pos - link))

-- | Compute an angular direction between two vectors.
angleDir :: Vector -> Vector -> Float
angleDir (x, y) (u, v) = signum (x * v - y * u)

-- | Make snake's tail its head, change direction and remove target.
reverseSnake :: Snake -> Snake
reverseSnake snake@Snake{..} = snake
  { snakeLinks  = newLinks
  , snakeDir    = normalizeV (a - b)
  , snakeTarget = Nothing }
  where
    newLinks = reverse snakeLinks
    a:b:_ = newLinks

