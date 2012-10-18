/*
 Copyright (c) 2008 LightSPEED Technologies, Inc.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "USParserApplication.h"

#import "STSTemplateEngine.h"


@implementation USParserApplication

@dynamic wsdlURL;
@dynamic outURL;
@dynamic statusString;
@dynamic parsing;

- (id)init
{
	if((self = [super init])) {
		NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
		[defaults addObserver:self forKeyPath:@"values.wsdlPath" options:0 context:nil];
		[defaults addObserver:self forKeyPath:@"values.outPath" options:0 context:nil];
		
		statusString = nil;
		
		parsing = NO;
	}
	
	return self;
}
		 
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([keyPath isEqualToString:@"values.wsdlPath"] ||
	   [keyPath isEqualToString:@"values.outPath"]) {
		[self willChangeValueForKey:@"canParseWSDL"];
		[self didChangeValueForKey:@"canParseWSDL"];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (BOOL)canParseWSDL
{
	if([self disableAllControls]) return NO;
	
	return (self.wsdlURL != nil && self.outURL != nil);
}

- (NSURL *)wsdlURL
{
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	
	NSString *pathString = [defaults valueForKeyPath:@"values.wsdlPath"];
	
	if(pathString == nil) return nil;
	if ([pathString length] == 0) return nil;

	if([pathString characterAtIndex:0] == '/') {
		return [NSURL fileURLWithPath:pathString];
	}
	
	return [NSURL URLWithString:pathString];
}

- (NSURL *)outURL
{
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
	
	NSString *pathString = [defaults valueForKeyPath:@"values.outPath"];
	
	if(pathString == nil) return nil;
	if ([pathString length] == 0) return nil;
	
	if([pathString characterAtIndex:0] == '/') {
		return [NSURL fileURLWithPath:pathString];
	}

	return [NSURL URLWithString:pathString];
}


- (IBAction)browseWSDL:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setResolvesAliases:YES];
	[panel setAllowsMultipleSelection:NO];
	[panel setAllowedFileTypes:[NSArray arrayWithObject:@"wsdl"]];

	if([panel runModal] == NSOKButton) {
		NSString *chosenPath = [[[panel URLs] lastObject] path];
		NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
		[defaults setValue:chosenPath forKeyPath:@"values.wsdlPath"];
	}
}

- (IBAction)browseOutput:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	[panel setResolvesAliases:YES];
	[panel setAllowsMultipleSelection:NO];
    [panel setCanCreateDirectories:YES];
	
	if([panel runModal] == NSOKButton) {
		NSString *chosenPath = [[[panel URLs] lastObject] path];
		NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
		[defaults setValue:chosenPath forKeyPath:@"values.outPath"];
	}
}

- (BOOL)disableAllControls
{
	return parsing;
}

- (IBAction)parseWSDL:(id)sender
{
	if(!parsing) [NSThread detachNewThreadSelector:@selector(doParseWSDL) toTarget:self withObject:nil];
}

- (void)setStatusString:(NSString *)aString
{
	[self willChangeValueForKey:@"statusString"];
	
	statusString = [aString copy];
	
	[self didChangeValueForKey:@"statusString"];
}

- (void)setParsing:(BOOL)aBool
{
	[self willChangeValueForKey:@"canParseWSDL"];
	[self willChangeValueForKey:@"disableAllControls"];
	
	parsing = aBool;
	
	[self didChangeValueForKey:@"disableAllControls"];
	[self didChangeValueForKey:@"canParseWSDL"];
}

- (void)parseWSDL:(NSURL *)wsdlURL outputDirectory:(NSURL *)outputDirURL
{
	@autoreleasepool {
	
		self.parsing = YES;
		
		self.statusString = @"Parsing WSDL file...";
		
		USParser *parser = [[USParser alloc] initWithURL:wsdlURL];
		USWSDL *wsdl = [parser parse];
		
		self.statusString = @"Writing debug info to console...";
		
		[self writeDebugInfoForWSDL:wsdl];
		
		
		self.statusString = @"Generating Objective C code into the output directory...";
		
		USWriter *writer = [[USWriter alloc] initWithWSDL:wsdl outputDirectory:outputDirURL];
		[writer write];
		
		self.statusString = @"Finished!";
		
		self.parsing = NO;
	
	}
}

- (void)doParseWSDL
{
	[self parseWSDL:self.wsdlURL outputDirectory:self.outURL];
}

-(void)writeDebugInfoForWSDL: (USWSDL*)wsdl
{
	if(!wsdl)
	{
		NSLog(@"No WSDL!!");
		return;
	}
	
	if(NO) //write out schemas
	{
		for(USSchema *schema in wsdl.schemas)
		{
			NSLog(@"Schema: %@", [schema fullName]);
			
			if(NO) //write out types
			{
				for(USType * t in [schema types])
				{
					if([t isComplexType])
					{
						NSLog(@"\tComplex type: %@", t.typeName);
						for(USAttribute *at in t.attributes)
						{
							if([at.type isSimpleType])
							{
								USType *st = at.type;
								NSLog(@"\t\tSimple Type attribute: %@, type: %@ representation: %@, default: %@",at.name, st.typeName, st.representationClass, at.attributeDefault);
							}
							else
							{
								USType *act = at.type;
								NSString *baseClass = @"No base";
								if(act.superClass)
									baseClass = act.superClass.typeName;
								NSLog(@"\t\tComplex type attribute: %@, type: %@, base: %@, default: %@", at.name, act.typeName, baseClass, at.attributeDefault);
							}
						}
					}
					else
					{
						NSLog(@"\tSimple type: %@, representation class: %@", t.typeName, t.representationClass);
						if([t.enumerationValues count] > 0)
						{
							NSLog(@"\t\tEnumeration values: ");
							for(NSString *v in t.enumerationValues)
							{
								NSLog(@"\t\t\t%@", v);
							}
						}
					}
				}
			}
		}
		
			}
	
	if(YES) //write potential problems
	{
		for(USSchema *schema in wsdl.schemas)
		{
			if([schema.types count] == 0)
			{
			}
		}
		
	}
}
@end
