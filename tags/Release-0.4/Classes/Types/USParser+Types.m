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

#import "USParser+Types.h"

#import "USWSDL.h"
#import "USSchema.h"
#import "USType.h"
#import "USSequenceElement.h"
#import "USAttribute.h"
#import "USElement.h"

@implementation USParser (Types)

#pragma mark Types
- (void)processTypesElement:(NSXMLElement *)el wsdl:(USWSDL *)wsdl
{
	for(NSXMLNode *child in [el children]) {
		if([child kind] == NSXMLElementKind) {
			[self processTypesChildElement:(NSXMLElement*)child wsdl:wsdl];
		}
	}
}

- (void)processTypesChildElement:(NSXMLElement *)el wsdl:(USWSDL *)wsdl
{
	NSString *localName = [el localName];
	
	if([localName isEqualToString:@"schema"]) {
		[self processSchemaElement:el wsdl:wsdl];
	} else if([localName isEqualToString:@"import"]) {
		[self processImportElement:el wsdl:wsdl];
	}
}

#pragma mark Types:Schema:SimpleType
- (void)processSimpleTypeElement:(NSXMLElement *)el schema:(USSchema *)schema
{
	NSString *typeName = [[el attributeForName:@"name"] stringValue];
	
	USType *type = [schema typeForName:typeName];
	
	if(!type.hasBeenParsed) {
		type.behavior = TypeBehavior_simple;
		
		for(NSXMLNode *child in [el children]) {
			if([child kind] == NSXMLElementKind) {
				[self processSimpleTypeChildElement:(NSXMLElement*)child type:type];
			}
		}
		
		type.hasBeenParsed = YES;
	}
}

- (void)processSimpleTypeChildElement:(NSXMLElement *)el type:(USType *)type
{
	NSString *localName = [el localName];
	
	if([localName isEqualToString:@"restriction"]) {
		[self processRestrictionElement:el type:type];
	}
}

- (void)processRestrictionElement:(NSXMLElement *)el type:(USType *)type
{
	NSString *base = [[el attributeForName:@"base"] stringValue];
	
	NSString *uri = [[el resolveNamespaceForName:base] stringValue];
	NSString *name = [NSXMLNode localNameForName:base];
	
	USSchema *schema = type.schema;
	USWSDL *wsdl = schema.wsdl;
	
	USType *baseType = [wsdl typeForNamespace:uri name:name];
	if(baseType == nil) {
		type.representationClass = base;
	} else {
		if([baseType isSimpleType]) {
			type.representationClass = baseType.representationClass;
		}
	}
	
	for(NSXMLNode *child in [el children]) {
		if([child kind] == NSXMLElementKind) {
			[self processRestrictionChildElement:(NSXMLElement*)child type:type];
		}
	}
}

- (void)processRestrictionChildElement:(NSXMLElement *)el type:(USType *)type
{
	NSString *localName = [el localName];
	
	if([localName isEqualToString:@"enumeration"]) {
		[self processEnumerationElement:el type:type];
	}
}

- (void)processEnumerationElement:(NSXMLElement *)el type:(USType *)type
{
	NSString *enumerationValue = [[el attributeForName:@"value"] stringValue];
	[type.enumerationValues addObject:enumerationValue];
}

#pragma mark Types:Schema:ComplexType
- (void)processComplexTypeElement:(NSXMLElement *)el schema:(USSchema *)schema
{
	NSString *typeName = [[el attributeForName:@"name"] stringValue];
	
	USType *type = [schema typeForName:typeName];
	
	if(!type.hasBeenParsed) {
		type.behavior = TypeBehavior_complex;
		
		for(NSXMLNode *child in [el children]) {
			if([child kind] == NSXMLElementKind) {
				[self processComplexTypeChildElement:(NSXMLElement*)child type:type];
			}
		}
		
		type.hasBeenParsed = YES;
	}
}

- (void)processComplexTypeChildElement:(NSXMLElement *)el type:(USType *)type
{
	NSString *localName = [el localName];
	
	if([localName isEqualToString:@"sequence"]) {
		[self processSequenceElement:el type:type];
	} else if([localName isEqualToString:@"attribute"]) {
		[self processAttributeElement:el type:type];
	} else if([localName isEqualToString:@"complexContent"]) {
		[self processComplexContentElement:el type:type];
	}
}

- (void)processAttributeElement:(NSXMLElement *)el type:(USType *)type
{
	USAttribute *attribute = [[USAttribute new] autorelease];
	
	NSString *name = [[el attributeForName:@"name"] stringValue];
	attribute.name = name;
	
	NSString *prefixedType = [[el attributeForName:@"type"] stringValue];
	NSString *uri = [[el resolveNamespaceForName:prefixedType] stringValue];
	NSString *typeName = [NSXMLNode localNameForName:prefixedType];
	USType *attributeType = [type.schema.wsdl typeForNamespace:uri name:typeName];
	attribute.type = attributeType;
	
	NSXMLNode *defaultNode = [el attributeForName:@"default"];
	if(defaultNode != nil) {
		NSString *defaultValue = [defaultNode stringValue];
		attribute.attributeDefault = defaultValue;
	}
	
	[type.attributes addObject:attribute];
}

- (void)processSequenceElement:(NSXMLElement *)el type:(USType *)type
{
	for(NSXMLNode *child in [el children]) {
		if([child kind] == NSXMLElementKind) {
			[self processSequenceChildElement:(NSXMLElement*)child type:type];
		}
	}
}

- (void)processSequenceChildElement:(NSXMLElement *)el type:(USType *)type
{
	NSString *localName = [el localName];
	
	if([localName isEqualToString:@"element"]) {
		[self processSequenceElementElement:el type:type];
	}
}

- (void)processSequenceElementElement:(NSXMLElement *)el type:(USType *)type
{
	USSequenceElement *seqElement = [[USSequenceElement new] autorelease];
	
	NSXMLNode *refNode = [el attributeForName:@"ref"];
	if(refNode != nil) {
		
		NSString *elementQName = [refNode stringValue];
		NSString *elementURI = [[el resolveNamespaceForName:elementQName] stringValue];
		NSString *elementLocalName = [NSXMLNode localNameForName:elementQName];
		
		USSchema *schema = [type.schema.wsdl schemaForNamespace:elementURI];
		USElement *element = [schema elementForName:elementLocalName];
		
		if(element.hasBeenParsed) {
			seqElement.name = element.name;
			seqElement.type = element.type;
		} else {
			[element.waitingSeqElements addObject:seqElement];
		}
		
		
	} else {
		
		NSString *name = [[el attributeForName:@"name"] stringValue];
		seqElement.name = name;
		
		NSString *prefixedType = [[el attributeForName:@"type"] stringValue];
		NSString *uri = [[el resolveNamespaceForName:prefixedType] stringValue];
		NSString *typeName = [NSXMLNode localNameForName:prefixedType];
		seqElement.type = [type.schema.wsdl typeForNamespace:uri name:typeName];
		
	}
	
	NSXMLNode *minOccursNode = [el attributeForName:@"minOccurs"];
	if(minOccursNode != nil) {
		seqElement.minOccurs = [[minOccursNode stringValue] intValue];
	} else {
		seqElement.minOccurs = 0;
	}
	
	NSXMLNode *maxOccursNode = [el attributeForName:@"maxOccurs"];
	if(maxOccursNode != nil) {
		NSString *maxOccursValue = [maxOccursNode stringValue];
		
		if([maxOccursValue isEqualToString:@"unbounded"]) {
			seqElement.maxOccurs = -1;
		} else {
			seqElement.maxOccurs = [maxOccursValue intValue];
		}
	} else {
		seqElement.maxOccurs = 0;
	}
	
	[type.sequenceElements addObject:seqElement];
}

- (void)processComplexContentElement:(NSXMLElement *)el type:(USType *)type
{
	for(NSXMLNode *child in [el children]) {
		if([child kind] == NSXMLElementKind) {
			[self processComplexContentChildElement:(NSXMLElement*)child type:type];
		}
	}
}

- (void)processComplexContentChildElement:(NSXMLElement *)el type:(USType *)type
{
	NSString *localName = [el localName];
	
	if([localName isEqualToString:@"extension"]) {
		[self processExtensionElement:el type:type];
	}
}

- (void)processExtensionElement:(NSXMLElement *)el type:(USType *)type
{
	NSString *prefixedType = [[el attributeForName:@"base"] stringValue];
	NSString *uri = [[el resolveNamespaceForName:prefixedType] stringValue];
	NSString *typeName = [NSXMLNode localNameForName:prefixedType];
	USType *baseType = [type.schema.wsdl typeForNamespace:uri name:typeName];
	
	type.superClass = baseType;
	
	for(NSXMLNode *child in [el children]) {
		if([child kind] == NSXMLElementKind) {
			[self processExtensionChildElement:(NSXMLElement*)child type:type];
		}
	}
}

- (void)processExtensionChildElement:(NSXMLElement *)el type:(USType *)type
{
	[self processComplexTypeChildElement:el type:type];
}

#pragma mark Types:Schema:Element
- (void)processElementElement:(NSXMLElement *)el schema:(USSchema *)schema
{
	NSString *elementName = [[el attributeForName:@"name"] stringValue];
	USElement *element = [schema elementForName:elementName];
	
	if(!element.hasBeenParsed) {
		NSString *prefixedType = [[el attributeForName:@"type"] stringValue];
		
		if(prefixedType != nil) {
			NSString *uri = [[el resolveNamespaceForName:prefixedType] stringValue];
			NSString *typeName = [NSXMLNode localNameForName:prefixedType];
			USType *type = [schema.wsdl typeForNamespace:uri name:typeName];
			element.type = type;
			
			for(USSequenceElement *seqElement in element.waitingSeqElements) {
				seqElement.name = element.name;
				seqElement.type = element.type;
			}
		} else {
			for(NSXMLNode *child in [el children]) {
				if([child kind] == NSXMLElementKind) {
					[self processElementElementChildElement:(NSXMLElement*)child element:element];
				}
			}
		}
		
		element.hasBeenParsed = YES;
	}
}

- (void)processElementElementChildElement:(NSXMLElement *)el element:(USElement *)element
{
	NSString *localName = [el localName];
	
	if([localName isEqualToString:@"complexType"]) {
		[self processElementElementComplexTypeElement:el element:element];
	}
}

- (void)processElementElementComplexTypeElement:(NSXMLElement *)el element:(USElement *)element
{
	USType *type = [element.schema typeForName:element.name];
	
	if(!type.hasBeenParsed) {
		type.behavior = TypeBehavior_complex;
		type.hasBeenParsed = YES;
	}
	
	element.type = type;
}

@end
