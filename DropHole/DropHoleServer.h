//
//  DropHoleServer.h
//  DropHole
//
//  Created by Nevyn Bengtsson on 2015-02-25.
//  Copyright (c) 2015 ThirdCog. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol DropHoleServerDelegate;
@class DropHoleFileTransferRequest, DropHoleFileTransferStatus;

typedef DropHoleFileTransferStatus*(^DropHoleURLProvider)(NSURL*);

@interface DropHoleServer : NSObject
- (id)initWithDelegate:(id<DropHoleServerDelegate>)delegate;
@end

@protocol DropHoleServerDelegate <NSObject>
// return nil to reject request
- (void)server:(DropHoleServer*)server destinationForTransferRequest:(DropHoleFileTransferRequest*)request callback:(DropHoleURLProvider)callback;
@end

@interface DropHoleFileTransferRequest : NSObject
@property(nonatomic) NSString *filename;
@property(nonatomic) NSString *senderName;
@property(nonatomic) int64_t fileSize;
@property(nonatomic) NSData *imageData;
@end

@interface DropHoleFileTransferStatus : NSObject
@property(nonatomic) DropHoleFileTransferRequest *request;
@property(nonatomic) NSURL *destination;
@property(nonatomic) int64_t bytesTransferred;
- (float)progress;
@end