//
//  FinderService.m
//  OneWay
//
//  Copyright 2010 Nick Jensen <http://goto11.net>
//

#import "FinderService.h"
#import "Location.h"
#import "FinderItem.h"
#import "OWConstants.h"
#import "NSString+UUID.h"


NSString * const OWXPathForPListTitleNode = @"./plist/dict/array/dict/dict/string";
NSString * const OWXPathForWorkflowScriptNode = @"./plist/dict/array/dict/dict/dict[4]/string";
NSString * const OWXPathForInputUID	= @"./plist/dict/array/dict/dict/string[7]";
NSString * const OWXPathForOutputUID = @"./plist/dict/array/dict/dict/string[8]";
NSString * const OWXPathForUID = @"./plist/dict/array/dict/dict/string[9]";


NSString * const OWUploadToNewLocationBundleName = @"OneWayUploadToNewLocation.workflow";

NSString * const OWUploadToNewLocationScript = @"on run {input, parameters}\n\ttell application \"OneWay\"\n\t\tqueue new transfer input\n\tend tell\n\treturn input\nend run";

NSString * const OWUploadToExistingLocationBundleName = @"OneWayUploadToLocation-%d.workflow";

NSString * const OWUploadToExistingLocationScript = @"on run {input, parameters}\n\ttell application \"OneWay\"\n\t\tset x to location %d\n\t\tqueue transfer x with files input\n\tend tell\n\treturn input\nend run";

@implementation FinderService


+ (void)updateForLocations:(NSArray *)locations
{
	[FinderService removeAllServices];
	
	[FinderService createServiceForNewLocation];
	
	for (int i = 0; i < [locations count]; i++)
	{
		[FinderService createServiceForLocation:(Location *)[locations objectAtIndex:i] 
										atIndex:i];
	}
}


+ (void)createServiceForNewLocation
{	
	NSXMLDocument *wflowDoc = [FinderService workflowDocument];
	NSXMLDocument *plistDoc = [FinderService plistDocument];
	
	NSXMLNode *titleNode = [[plistDoc nodesForXPath:OWXPathForPListTitleNode 
											  error:nil] objectAtIndex:0];
	
	NSXMLNode *scriptNode = [[wflowDoc nodesForXPath:OWXPathForWorkflowScriptNode
											error:nil] objectAtIndex:0];
	
	[titleNode setStringValue:[FinderItem labelForNewLocation]];
	
	[scriptNode setStringValue:OWUploadToNewLocationScript];
		
	[FinderService createServiceBundle:OWUploadToNewLocationBundleName 
					  withWorkflowData:wflowDoc 
							 plistData:plistDoc];
}


+ (void)createServiceForLocation:(Location *)location atIndex:(int)index
{
	NSXMLDocument *wflowDoc = [FinderService workflowDocument];
	NSXMLDocument *plistDoc = [FinderService plistDocument];
	
	NSXMLNode *titleNode = [[plistDoc nodesForXPath:OWXPathForPListTitleNode 
											  error:nil] objectAtIndex:0];
	
	NSXMLNode *scriptNode = [[wflowDoc nodesForXPath:OWXPathForWorkflowScriptNode
											   error:nil] objectAtIndex:0];
		
	[titleNode setStringValue:[FinderItem labelForLocation:location]];

	[scriptNode setStringValue:[NSString stringWithFormat:OWUploadToExistingLocationScript, (index + 1)]];
	
	[FinderService createServiceBundle:[NSString stringWithFormat:OWUploadToExistingLocationBundleName, (index + 1)]
					  withWorkflowData:wflowDoc 
							 plistData:plistDoc];	
}


+ (void)removeServiceAtIndex:(int)index
{
	NSString *bundlePath = [[OWServiceDirectory stringByExpandingTildeInPath] 
							stringByAppendingPathComponent:[NSString stringWithFormat:OWUploadToExistingLocationBundleName, (index + 1)]];
	
	NSFileManager *mgr = [[NSFileManager alloc] init];
	
	if ([mgr fileExistsAtPath:bundlePath])
	{
		[mgr removeItemAtPath:bundlePath error:nil];
	}
	
	[mgr release];
}

	 
+ (NSXMLDocument *)workflowDocument
{
	NSString *file = [[[NSBundle mainBundle] bundlePath]
					  stringByAppendingPathComponent:OWServiceWorkflowTemplate];
	NSXMLDocument *xmlDoc;
    NSError *err=nil;
    NSURL *furl = [NSURL fileURLWithPath:file];
	
    if (!furl) 
	{
        NSLog(@"Can't create URL from file %@.", file);		
        return nil;
    }
		
	xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:furl
												  options:NSXMLDocumentTidyXML
													error:&err];
	
	return xmlDoc;
}
	 

+ (NSXMLDocument *)plistDocument
{
	NSString *file = [[[NSBundle mainBundle] bundlePath]
					  stringByAppendingPathComponent:OWServicePListTemplate];
	
	NSXMLDocument *xmlDoc;
    NSError *err=nil;
    NSURL *furl = [NSURL fileURLWithPath:file];
	
    if (!furl) 
	{
        NSLog(@"Can't create URL from file %@.", file);		
        return nil;
    }
	
	xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:furl
												  options:NSXMLDocumentTidyXML
													error:&err];
	
	return xmlDoc;
}


+ (void)createServiceDirectory
{
	NSFileManager *mgr = [[NSFileManager alloc] init];
	
	if (![mgr fileExistsAtPath:[OWServiceDirectory stringByExpandingTildeInPath]])
	{
		[mgr createDirectoryAtPath:[OWServiceDirectory stringByExpandingTildeInPath] 
						attributes:nil];
	}
	
	[mgr release];
}


+ (void)createServiceBundle:(NSString *)name withWorkflowData:(NSXMLDocument *)workflow plistData:(NSXMLDocument *)plist
{
	[FinderService createServiceDirectory];
	
	NSXMLNode *uidNode	= [[workflow nodesForXPath:OWXPathForUID
											 error:nil] objectAtIndex:0];
	
	NSXMLNode *inputUidNode	= [[workflow nodesForXPath:OWXPathForInputUID
												 error:nil] objectAtIndex:0];

	NSXMLNode *outputUidNode = [[workflow nodesForXPath:OWXPathForOutputUID 
												  error:nil] objectAtIndex:0];

	[inputUidNode	setStringValue:[NSString stringWithNewUUID]];
	[outputUidNode	setStringValue:[NSString stringWithNewUUID]];
	[uidNode		setStringValue:[NSString stringWithNewUUID]];
	
	NSString *bundlePath = [[OWServiceDirectory stringByExpandingTildeInPath] stringByAppendingPathComponent:name];	
	NSString *contentsPath = [bundlePath stringByAppendingPathComponent:@"Contents"];
	NSString *quicklookPath = [contentsPath stringByAppendingPathComponent:@"QuickLook"];
	
	NSFileManager *mgr = [[NSFileManager alloc] init];
	
	[mgr createDirectoryAtPath:bundlePath 
					attributes:nil];
	
	[mgr createDirectoryAtPath:contentsPath
					attributes:nil];
	
	[mgr createDirectoryAtPath:quicklookPath
					attributes:nil];
	
	[mgr createFileAtPath:[contentsPath stringByAppendingPathComponent:@"document.wflow"]
				 contents:[workflow XMLData]
			   attributes:nil];
	 
	[mgr createFileAtPath:[contentsPath stringByAppendingPathComponent:@"Info.plist"]
				 contents:[plist XMLData]
			   attributes:nil];
	
	NSString *thumbnailSource = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:OWServiceThumbnail];
	
	[mgr copyItemAtPath:thumbnailSource 
				 toPath:[quicklookPath stringByAppendingPathComponent:@"Thumbnail.png"] 
				  error:nil]; 

	[mgr release];
}


+ (void)reload
{
	NSTask *task;
	task = [[[NSTask alloc] init] autorelease];
	[task setStandardInput:[NSPipe pipe]];
	[task setLaunchPath: @"/System/Library/CoreServices/pbs"];
	
	NSArray *args;
    args = [NSArray arrayWithObjects: @"en", nil];
    [task setArguments: args];
	
	[task launch];
}


+ (void)removeAllServices
{
	NSTask *task;
	task = [[[NSTask alloc] init] autorelease];
	
	NSString * scriptPath = [[[NSBundle mainBundle] bundlePath] 
								stringByAppendingPathComponent:OWRemoveServicesScript];

	[task setStandardInput:[NSPipe pipe]];
	[task setLaunchPath:scriptPath];	
	[task launch];
	[task waitUntilExit];
}


@end
