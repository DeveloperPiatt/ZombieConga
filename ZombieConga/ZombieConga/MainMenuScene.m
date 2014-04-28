//
//  MainMenuScene.m
//  ZombieConga
//
//  Created by NickPiatt on 4/27/14.
//  Copyright (c) 2014 iPiatt. All rights reserved.
//

#import "MainMenuScene.h"
#import "MyScene.h"

@implementation MainMenuScene

-(id)initWithSize:(CGSize)size
{
    if (self = [super initWithSize:size]) {
        self.backgroundColor = [SKColor whiteColor];
        SKSpriteNode *bg = [SKSpriteNode spriteNodeWithImageNamed:@"MainMenu.png"];
        bg.name = @"mainMenu";
        bg.position =CGPointMake(self.size.width/2, self.size.height/2);
        [self addChild:bg];     
    }
    return self;
}

-(void)startGame
{
    SKScene *gameScene = [[MyScene alloc] initWithSize:self.size];
    SKTransition *reveal = [SKTransition doorwayWithDuration:0.5];
    [self.view presentScene:gameScene transition:reveal];
}

-(void)touchesBegan:(NSSet *)touches
          withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:self];
    
    SKSpriteNode *touchedNode = (SKSpriteNode*)[self nodeAtPoint:touchLocation];
    
    if ([touchedNode.name isEqualToString:@"mainMenu"]) {
        [self startGame];
    }
    
}

@end
