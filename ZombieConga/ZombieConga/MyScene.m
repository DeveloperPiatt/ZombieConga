//
//  MyScene.m
//  ZombieConga
//
//  Created by NickPiatt on 4/1/14.
//  Copyright (c) 2014 iPiatt. All rights reserved.
//

@import AVFoundation;

#import "MyScene.h"
#import "GameOverScene.h"


#define ARC4RANDOM_MAX  0x100000000
static inline CGFloat ScalarRandomRange(CGFloat min, CGFloat max)
{
    return floorf(((double)arc4random() / ARC4RANDOM_MAX) * (max - min) + min );
}

static inline CGFloat ScalarSign(CGFloat a)
{
    return a >= 0 ? 1: -1;
}

// Returns shortest angle between two angles,
// between -M_PI and M_PI
static inline CGFloat ScalarShortestAngleBetween(const CGFloat a, const CGFloat b)
{
    CGFloat difference = b - a;
    CGFloat angle = fmodf(difference, M_PI * 2);
    if (angle >= M_PI) {
        angle -= M_PI * 2;
    }
    else if (angle <= -M_PI) {
        angle += M_PI * 2;
    }
    return angle;
}

static inline CGPoint CGPointAdd(const CGPoint a, const CGPoint b)
{
    return CGPointMake(a.x + b.x, a.y + b.y);
}

static inline CGPoint CGPointSubtract(const CGPoint a, const CGPoint b)
{
    return CGPointMake(a.x - b.x, a.y - b.y);
}

static inline CGPoint CGPointMultiplyScaler(const CGPoint a, const CGFloat b)
{
    return CGPointMake(a.x * b, a.y * b);
}

static inline CGFloat CGPointLength(const CGPoint a)
{
    return sqrtf(a.x * a.x + a.y * a.y);
}

static inline CGPoint CGPointNormalize(const CGPoint a)
{
    CGFloat length = CGPointLength(a);
    return CGPointMake(a.x / length, a.y / length);
}

static inline CGFloat CGPointToAngle(const CGPoint a)
{
    return atan2f(a.y, a.x);
}

static const float ZOMBIE_MOVE_POINTS_PER_SEC = 120.0;
static const float ZOMBIE_ROTATE_RADIANS_PER_SEC = 4 * M_PI;
static const float CAT_MOVE_POINTS_PER_SEC = 120.0;

@implementation MyScene
{
    SKSpriteNode *_zombie;
    NSTimeInterval _lastUpdateTime;
    NSTimeInterval _dt;
    CGPoint _velocity;
    
    CGPoint _lastTouchedLocation;
    
    SKAction *_zombieAnimation;
    
    SKAction *_catCollisionSound;
    SKAction *_enemyCollisionSound;
    
    AVAudioPlayer *_backgroundMusicPlayer;
    
    BOOL _isInvincible;
    
    int _lives;
    BOOL _gameOver;
}

-(id)initWithSize:(CGSize)size
{
    if (self = [super initWithSize:size]) {
        self.backgroundColor = [SKColor whiteColor];
        
        _lives = 5;
        _gameOver = NO;
        [self playBackgroundMusic:@"bgMusic.mp3"];
        
        SKSpriteNode *bg = [SKSpriteNode spriteNodeWithImageNamed:@"background"];
        bg.position = CGPointMake(self.size.width/2, self.size.height/2);
        [self addChild:bg];
        
        // Add Zombie
        _zombie = [SKSpriteNode spriteNodeWithImageNamed:@"zombie1"];
        _zombie.position = CGPointMake(100, 100);
        _zombie.zPosition = 100;
        _isInvincible = FALSE;
        [self addChild:_zombie];
        NSMutableArray *textures = [NSMutableArray arrayWithCapacity:10];
        for (int i = 1; i<4; i++) {
            NSString *textureName = [NSString stringWithFormat:@"zombie%d", i];
            SKTexture *texture = [SKTexture textureWithImageNamed:textureName];
            [textures addObject:texture];
        }
        
        for (int i = 4; i>1; i--) {
            NSString *textureName = [NSString stringWithFormat:@"zombie%d", i];
            SKTexture *texture = [SKTexture textureWithImageNamed:textureName];
            [textures addObject:texture];
        }
        
        _zombieAnimation = [SKAction animateWithTextures:textures timePerFrame:0.1];
        
//        [_zombie runAction:[SKAction repeatActionForever:_zombieAnimation]];
        
        // Spawn Enemies
        [self runAction:[SKAction repeatActionForever:
                         [SKAction sequence:@[[SKAction performSelector:@selector(spawnEnemy) onTarget:self],
                                              [SKAction waitForDuration:2.0]]]]];
        // Spawn Cats
        [self runAction:[SKAction repeatActionForever:
                         [SKAction sequence:@[[SKAction performSelector:@selector(spawnCat) onTarget:self],
                                              [SKAction waitForDuration:1.0]]]]];
        
        _catCollisionSound = [SKAction playSoundFileNamed:@"hitCat.wav" waitForCompletion:NO];
        _enemyCollisionSound = [SKAction playSoundFileNamed:@"hitCatLady.wav" waitForCompletion:NO];
    }
    return self;
}

-(void)update:(NSTimeInterval)currentTime
{
    // Time Intervals
    
    if (_lastUpdateTime) {
        _dt = currentTime - _lastUpdateTime;
    } else {
        _dt = 0;
    }
    
    _lastUpdateTime = currentTime;
    //NSLog(@"%0.2f milliseconds since last update", _dt * 1000);
    
    CGPoint offset = CGPointSubtract(_lastTouchedLocation, _zombie.position);
    float distance = CGPointLength(offset);
    
    if (distance <= ZOMBIE_MOVE_POINTS_PER_SEC * _dt) {
        _zombie.position = _lastTouchedLocation;
        _velocity = CGPointZero;
        [self stopZombieAnimation];
    } else {
        [self moveSprite:_zombie velocity:_velocity];
        [self boundsCheckPlayer];
        [self rotateSprite:_zombie toFace:_velocity rotateRadiansPerSec:ZOMBIE_ROTATE_RADIANS_PER_SEC];
    }
    [self moveTrain];
    
    if (_lives <= 0 && !_gameOver) {
        _gameOver = YES;
        NSLog(@"You lose!");
        [_backgroundMusicPlayer stop];
        
        SKScene *gameOverScene = [[GameOverScene alloc] initWithSize:self.size won:NO];
        
        SKTransition *reveal = [SKTransition flipHorizontalWithDuration:0.5];
        
        [self.view presentScene:gameOverScene transition:reveal];
    }
}

- (void)didEvaluateActions
{
    [self checkCollisions];
}

-(void)boundsCheckPlayer
{
    // 1
    CGPoint newPosition = _zombie.position;
    CGPoint newVelocity = _velocity;
    
    // 2
    CGPoint bottomLeft = CGPointZero;
    CGPoint topRight = CGPointMake(self.size.width, self.size.height);
    
    // 3
    if (newPosition.x <= bottomLeft.x) {
        newPosition.x = bottomLeft.x;
        newVelocity.x = -newVelocity.x;
    }
    if (newPosition.x >= topRight.x) {
        newPosition.x = topRight.x;
        newVelocity.x = -newVelocity.x;
    }
    if (newPosition.y <= bottomLeft.y) {
        newPosition.y = bottomLeft.y;
        newVelocity.y = -newVelocity.y;
    }
    if (newPosition.y >= topRight.y) {
        newPosition.y = topRight.y;
        newVelocity.y = -newVelocity.y;
    }
    
    // 4
    _zombie.position = newPosition;
    _velocity = newVelocity;
}

- (void)checkCollisions
{
    [self enumerateChildNodesWithName:@"cat" usingBlock:^(SKNode *node, BOOL *stop){
        SKSpriteNode *cat = (SKSpriteNode *)node;
        if (CGRectIntersectsRect(cat.frame, _zombie.frame)) {
            //[cat removeFromParent];
            [self runAction:_catCollisionSound];
            
            cat.name = @"train";
            [cat removeAllActions];
            [cat setScale:1];
            cat.zRotation = 0;
            [cat runAction:[SKAction sequence:@[
                                                [SKAction colorizeWithColor:[SKColor greenColor] colorBlendFactor:1.0 duration:.2]
                                                ]]];
        }
    }];
    
    if (!_isInvincible) {
        [self enumerateChildNodesWithName:@"enemy" usingBlock:^(SKNode *node, BOOL *stop){
            SKSpriteNode *enemy = (SKSpriteNode *)node;
            CGRect smallerFrame = CGRectInset(enemy.frame, 20, 20);
            if (CGRectIntersectsRect(smallerFrame, _zombie.frame)) {
                [self runAction:_enemyCollisionSound];
                
                [self loseCats];
                _lives--;

                _isInvincible = true;
                
                float blinkTimes = 10;
                float blinkDuration = 3.0;
                SKAction *blinkAction = [SKAction customActionWithDuration:blinkDuration
                                                               actionBlock:^(SKNode *node, CGFloat elapsedTime) {
                                                                   float slice = blinkDuration / blinkTimes;
                                                                   float remainder = fmodf(elapsedTime, slice);
                                                                   _zombie.hidden = remainder > slice / 2;
                                                               }];
                
                SKAction *showZombieAction = [SKAction runBlock:^{
                    _zombie.hidden = FALSE;
                    _isInvincible = FALSE;
                }];
                
                SKAction *blinkSequence = [SKAction sequence:@[blinkAction, showZombieAction]];
                
                [_zombie runAction:blinkSequence];
            }
            
        }];
    }
    
}

- (void)loseCats
{
    __block int loseCount = 0;
    [self enumerateChildNodesWithName:@"train" usingBlock:^(SKNode *node, BOOL *stop) {
        CGPoint randomSpot = node.position;
        randomSpot.x += ScalarRandomRange(-100, 100);
        randomSpot.y += ScalarRandomRange(-100, 100);
        
        node.name = @"";
        [node runAction:
             [SKAction sequence:@[
                                  [SKAction group:@[
                                                    [SKAction rotateByAngle:M_PI * 4 duration:1.0],
                                                    [SKAction moveTo:randomSpot duration:1.0],
                                                    [SKAction scaleTo:0 duration:1.0]
                                                    ]],
                                  [SKAction removeFromParent]
                                  ]]];
        loseCount++;
        if (loseCount >= 2) {
            *stop = YES;
        }
    }];
}

-(void)moveSprite:(SKSpriteNode*)sprite
         velocity:(CGPoint)velocity
{
    // 1
    CGPoint amountToMove = CGPointMultiplyScaler(velocity, _dt);
    
    //NSLog(@"Amount to move: %@", NSStringFromCGPoint(amountToMove));
    
    // 2
    sprite.position = CGPointAdd(sprite.position, amountToMove);
}

- (void)moveTrain
{
    __block int trainCount = 0;
    __block CGPoint targetPosition = _zombie.position;
    [self enumerateChildNodesWithName:@"train" usingBlock:^(SKNode *node, BOOL *stop) {
        trainCount++;
        if (!node.hasActions) {
            float actionDuration = 0.3;
            CGPoint offset = CGPointSubtract(targetPosition, node.position);
            CGPoint direction = CGPointNormalize(offset);
            CGPoint amountToMovePerSec = CGPointMultiplyScaler(direction, CAT_MOVE_POINTS_PER_SEC);
            CGPoint amountToMove = CGPointMultiplyScaler(amountToMovePerSec, actionDuration);
            SKAction *moveAction = [SKAction moveByX:amountToMove.x y:amountToMove.y duration:actionDuration];
            [node runAction:moveAction];
        }
        targetPosition = node.position;
    }];
    
    if (trainCount >= 30 && !_gameOver) {
        _gameOver = YES;
        NSLog(@"You win!");
        [_backgroundMusicPlayer stop];
        SKScene *gameOverScene = [[GameOverScene alloc] initWithSize:self.size won:YES];
        
        SKTransition *reveal = [SKTransition flipHorizontalWithDuration:0.5];
        
        [self.view presentScene:gameOverScene transition:reveal];
    }
}

-(void)moveZombieToward:(CGPoint)location
{
    [self startZombieAnimation];
    CGPoint offset = CGPointSubtract(location, _zombie.position);
    CGPoint direction = CGPointNormalize(offset);
    _velocity = CGPointMultiplyScaler(direction, ZOMBIE_MOVE_POINTS_PER_SEC);
}

- (void)playBackgroundMusic:(NSString *)fileName
{
    NSError *error;
    NSURL *backgroundMusicURL = [[NSBundle mainBundle] URLForResource:fileName withExtension:nil];
    
    _backgroundMusicPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:backgroundMusicURL error:&error];
    _backgroundMusicPlayer.numberOfLoops = -1;
    [_backgroundMusicPlayer prepareToPlay];
    [_backgroundMusicPlayer play];
}

- (void)rotateSprite:(SKSpriteNode *)sprite
              toFace:(CGPoint)velocity
 rotateRadiansPerSec:(CGFloat)rotateRadiansPerSec
{
    CGFloat targetAngle = CGPointToAngle(velocity);
    CGFloat shortest = ScalarShortestAngleBetween(sprite.zRotation, targetAngle);
    
    CGFloat amtToRotate = rotateRadiansPerSec * _dt;
    
    if (ABS(shortest) < amtToRotate) {
        amtToRotate = ABS(shortest);
    }
    
    sprite.zRotation += amtToRotate * ScalarSign(shortest);
}

-(void)touchesBegan:(NSSet *)touches
          withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:self];
    
    _lastTouchedLocation = touchLocation;
    
    [self moveZombieToward:touchLocation];
}

-(void)touchesEnded:(NSSet *)touches
          withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:self];
    
    _lastTouchedLocation = touchLocation;
    
    [self moveZombieToward:touchLocation];
}

-(void)touchesMoved:(NSSet *)touches
          withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:self];
    
    _lastTouchedLocation = touchLocation;
    
    [self moveZombieToward:touchLocation];
}

- (void)spawnCat
{
    SKSpriteNode *cat = [SKSpriteNode spriteNodeWithImageNamed:@"cat"];
    cat.name = @"cat";
    cat.position = CGPointMake(ScalarRandomRange(0, self.size.width),
                               ScalarRandomRange(0, self.size.height));
    cat.xScale = 0;
    cat.yScale = 0;
    [self addChild:cat];
    
    cat.zRotation = -M_PI / 16;
    
    SKAction *appear = [SKAction scaleTo:1.0 duration:.5];
    
    SKAction *leftWiggle = [SKAction rotateByAngle:M_PI/8 duration:.5];
    SKAction *rightWiggle = [leftWiggle reversedAction];
    SKAction *fullWiggle = [SKAction sequence:@[leftWiggle, rightWiggle]];
    //SKAction *wiggleWait = [SKAction repeatAction:fullWiggle count:10];
    
    SKAction *scaleUp = [SKAction scaleBy:1.2 duration:.25];
    SKAction *scaleDown = [scaleUp reversedAction];
    SKAction *fullScale = [SKAction sequence:@[scaleUp,
                                               scaleDown,
                                               scaleUp,
                                               scaleDown]];
    SKAction *group = [SKAction group:@[fullScale, fullWiggle]];
    SKAction *groupWait = [SKAction repeatAction:group count:10];
    
    SKAction *disappear = [SKAction scaleTo:0 duration:.5];
    SKAction *removeFromParent = [SKAction removeFromParent];
    
    [cat runAction:[SKAction sequence:@[appear, groupWait, disappear, removeFromParent]]];
}

- (void)spawnEnemy
{
    SKSpriteNode *enemy = [SKSpriteNode spriteNodeWithImageNamed:@"enemy"];
    enemy.name = @"enemy";
    enemy.position = CGPointMake(self.size.width + enemy.size.width/2,
                                 ScalarRandomRange(enemy.size.height/2,
                                                   self.size.height-enemy.size.height/2));
    [self addChild:enemy];
    
    SKAction *actionMove = [SKAction moveToX:-enemy.size.width/2 duration:2.0];
    
    SKAction *actionRemove = [SKAction removeFromParent];
    [enemy runAction:[SKAction sequence:@[actionMove,
                                          actionRemove]]];
}

- (void)startZombieAnimation
{
    if (![_zombie actionForKey:@"animation"]) {
        [_zombie runAction:
         [SKAction repeatActionForever:_zombieAnimation]
                   withKey:@"animation"];
    }
}

- (void)stopZombieAnimation
{
    [_zombie removeActionForKey:@"animation"];
}

@end
