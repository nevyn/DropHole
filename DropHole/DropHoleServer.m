//
//  DropHoleServer.m
//  DropHole
//
//  Created by Nevyn Bengtsson on 2015-02-25.
//  Copyright (c) 2015 ThirdCog. All rights reserved.
//

#import "DropHoleServer.h"
#import <TCAsyncHashProtocol/TCAHPSimpleServer.h>
@protocol DropHoleClientHandlerDelegate;

@interface DropHoleClientHandler : NSObject <TCAHPSimpleServerDelegate>
{
	__weak id<DropHoleClientHandlerDelegate> _delegate;
}
- (id)initWithProto:(TCAsyncHashProtocol*)proto delegate:(id<DropHoleClientHandlerDelegate>)delegate;
@end

@protocol DropHoleClientHandlerDelegate <NSObject>
- (void)handler:(DropHoleClientHandler*)handler disconnectedWithError:(NSError*)err;
- (void)handler:(DropHoleClientHandler *)handler requestsDestinationFor:(DropHoleFileTransferRequest*)request callback:(DropHoleURLProvider)callback;
@end


@interface DropHoleServer () <DropHoleClientHandlerDelegate, TCAHPSimpleServerDelegate>
{
	TCAHPSimpleServer *_server;
	NSMutableSet *_handlers;
}
@property(weak) id<DropHoleServerDelegate> delegate;
@end

@implementation DropHoleServer
- (id)initWithDelegate:(id<DropHoleServerDelegate>)delegate
{
	if(!(self = [super init]))
		return nil;
	
	_delegate = delegate;
	
	NSError *err;
	_server = [[TCAHPSimpleServer alloc]
		initOnBasePort:26731
		serviceType:@"_drophope._tcp"
		serviceName:@""
		delegate:self
		error:&err
	];
	if(!_server) {
		NSLog(@"%@", err);
		return nil;
	}
	
	return self;
}

- (void)server:(TCAHPSimpleServer*)server acceptedNewClient:(TCAsyncHashProtocol*)proto
{
	DropHoleClientHandler *handler = [[DropHoleClientHandler alloc] initWithProto:proto delegate:self];
	[_handlers addObject:handler];
}

- (void)handler:(DropHoleClientHandler*)handler disconnectedWithError:(NSError*)err
{
	[_handlers removeObject:handler];
}

- (void)handler:(DropHoleClientHandler *)handler requestsDestinationFor:(DropHoleFileTransferRequest*)req callback:(DropHoleURLProvider)callback
{
	[_delegate server:self destinationForTransferRequest:req callback:callback];
}
@end

@implementation DropHoleClientHandler
{
	NSURL *_destination;
	NSFileHandle *_outHandle;
	DropHoleFileTransferStatus *_status;
}
- (id)initWithProto:(TCAsyncHashProtocol*)proto delegate:(id<DropHoleClientHandlerDelegate>)delegate
{
	if(!(self = [super init]))
		return nil;
	
	_status = [DropHoleFileTransferStatus new];
	proto.delegate = self;
	proto.autoDispatchCommands = YES;
	
	return self;
}

- (void)transportDidDisconnect:(TCAHPTransport*)transport
{
	if(_outHandle) {
		[_outHandle closeFile];
		[_delegate handler:self disconnectedWithError:[NSError errorWithDomain:@"eu.thirdcog" code:2389 userInfo:@{NSLocalizedDescriptionKey: @"File couldn't be transferred; socket closed"}]];
	} else {
		[_delegate handler:self disconnectedWithError:nil];
	}
}

- (void)request:(TCAsyncHashProtocol*)proto askToTransferFile:(NSDictionary*)hash responder:(TCAsyncHashProtocolResponseCallback)callback
{
	DropHoleFileTransferRequest *req = [DropHoleFileTransferRequest new];
	req.filename = hash[@"filename"];
	req.senderName = hash[@"senderName"];
	req.imageData = hash[@"imageData"];
	req.fileSize = [hash[@"fileSize"] longLongValue];
	_status.request = req;
	[_delegate handler:self requestsDestinationFor:req callback:^DropHoleFileTransferStatus*(NSURL *destination) {
		if(!destination) {
			[proto.transport disconnect];
			return nil;
		} else {
			_status.destination = _destination = destination;
			NSError *err;
			_outHandle = [NSFileHandle fileHandleForWritingToURL:_destination error:&err];
			if(!_outHandle) {
				NSLog(@":( %@", err);
				[proto.transport disconnect];
				return nil;
			}
			[_outHandle seekToEndOfFile];
			callback(@{@"acceptance": @YES});
			return _status;
		}
	}];
}

- (void)command:(TCAsyncHashProtocol*)proto transferChunk:(NSDictionary*)hash payload:(NSData*)payload
{
	[_outHandle writeData:payload];
	_status.bytesTransferred += payload.length;
	if([hash[@"lastPiece"] boolValue] == YES) {
		[_outHandle closeFile];
		_outHandle = nil;
	}
}

@end

@implementation DropHoleFileTransferRequest
@end
@implementation DropHoleFileTransferStatus
- (float)progress
{
	return (double)self.bytesTransferred / (double)self.request.fileSize;
}
@end
