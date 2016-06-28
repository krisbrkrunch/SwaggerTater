//
//  main.m
//  SwaggerTater
//
//  Created by Kris on 2016-06-06.
//  Copyright © 2016 KriscoDesigns. All rights reserved.
//

#import <Foundation/Foundation.h>
void IFPrint (NSString *format, ...) {
    //used to NSLog without \n
    va_list args;
    va_start(args, format);
    
    fputs([[[NSString alloc] initWithFormat:format arguments:args] UTF8String], stdout);
    
    va_end(args);
    
}
static NSString * trim(NSString* trimString)
{
    NSString *trimmedString = [trimString stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceCharacterSet]];
    return trimmedString;
}
static NSArray * processInputs(NSString *rootPath, NSString* file, NSString* funcName) {
    
    //split up php file path
    NSArray *phpparts = [file componentsSeparatedByString:@"\\"];
    NSString *newPath = @"";
    int i = 0;
    for (NSString *phppart in phpparts) {
        i++;
        //skip first 2 path componenants usually (App\Http\) which should be in our rootpath already
        if(i >2){
            newPath = [newPath stringByAppendingString:@"/"];
            newPath = [newPath stringByAppendingString:phppart];
           
        }
    }
    //open Controller file find function to document
    NSString *controller = [NSString stringWithContentsOfFile:[rootPath stringByAppendingString:newPath] encoding:kUnicodeUTF8Format error:nil];
    NSArray *contLines = [controller componentsSeparatedByString:@"\n"];
    int lncnt = 0;
    int fncOpenCnt = 0;
    int fncCloseCnt = 0;
    bool foundfunction =NO;
    bool functionEnded = NO;
    NSString *inputVar =@"";
    
    NSMutableArray *params = [NSMutableArray new];
    for (NSString *line in contLines) {
        lncnt++;
        
        if(foundfunction && !functionEnded){
            if([line rangeOfString:@"{"].location != NSNotFound)fncOpenCnt++;
            if([line rangeOfString:@"}"].location != NSNotFound){
                fncCloseCnt++;
                //check if close count matches open count signalling end of function.
                if(fncCloseCnt == fncOpenCnt)functionEnded = YES;
            }
            
            //look for input parameters to add
            if([line rangeOfString:@" = Input::all();"].location != NSNotFound){
                //found input variable reference
                //get variable name
                inputVar = trim([NSString stringWithFormat:@"$%@", [[line componentsSeparatedByString:@" = Input::all();"][0] componentsSeparatedByString:@"$"][1]]);
                //NSLog(@"%@", inputVar);
            }
            
           if([line rangeOfString:@"Input::get('"].location != NSNotFound){
               NSString *paramName2 = [[line componentsSeparatedByString:@"Input::get('"][1] componentsSeparatedByString:@"'"][0];
               bool foundpar = NO;
               for (NSString *par in params) {
                   if ([par isEqualToString:paramName2])foundpar = YES;
               }
               if(!foundpar)[params addObject:paramName2];
           }
            if([line rangeOfString:[NSString stringWithFormat:@"%@['", inputVar]].location != NSNotFound){
                //found input with inputvar
                NSString *paramName = [[line componentsSeparatedByString:[NSString stringWithFormat:@"%@['", inputVar]][1] componentsSeparatedByString:@"'"][0];
                bool foundpar = NO;
                for (NSString *par in params) {
                    if ([par isEqualToString:paramName])foundpar = YES;
                }
                if(!foundpar)[params addObject:paramName];
            }
        }
        if ([line rangeOfString:[NSString stringWithFormat:@"function %@(",funcName]].location != NSNotFound)
        {
           
            //found function name now we need loop through the rest of the function and find the input parameters but stop at end of function
            foundfunction = YES;
            if([line rangeOfString:@"{"].location != NSNotFound)fncOpenCnt++;
            //NSLog(@"%@ %@", newPath, line);
        }
        
    }
    //NSLog(@"%@",[params componentsJoinedByString:@""]);
    return [NSArray arrayWithArray:params];
    
}
const int getPaths(NSString* rootpath){
    //Utility function to get all files in folder for later expansion to doc all functions instead of seperate file
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL = [NSURL URLWithString:rootpath]; // URL pointing to the directory you want to browse
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:^(NSURL *url, NSError *error) {
                                             // Handle the error.
                                             // Return YES if the enumeration should continue after the error.
                                             return YES;
                                         }];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (! [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // handle error
        }
        else if (! [isDirectory boolValue]) {
            // No error and it’s not a directory; do something with the file
            NSLog(@"%@", [url absoluteString]);
        }else{
            
            NSLog(@"%@", [url absoluteString]);
        }
    }
    return 0;
}
int main(int argc, const char * argv[]) {
    @autoreleasepool {
       
        IFPrint(@"\nSwaggerTater v1.3\nBy Kris Bray\n Usage: SwaggerTater -lpath \"Path/To/LaravelFolder\" -filter \"api/\" \n");
        //get path args information from command line
        NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
        
        NSString *laravelPath = [standardDefaults stringForKey:@"lpath"];
        if(!laravelPath || [laravelPath isEqualToString:@""]){
            IFPrint(@"Must enter Laravel Path using -lpath");
            return 0;
        }
        
        int pid = [[NSProcessInfo processInfo] processIdentifier];
        //NSLog(@"PID: %i", pid);
        NSPipe *pipe = [NSPipe pipe];
        NSFileHandle *file = pipe.fileHandleForReading;
        
        NSTask *task = [[NSTask alloc] init];
        NSString *laravlPath = @"/Applications/AMPPS/tiktiks/laravel";
        NSString *rootPath = [NSString stringWithFormat:@"%@/app/Http", laravelPath];
        NSString *filtertext = @"api/";
        if([standardDefaults stringForKey:@"filter"] && ![[standardDefaults stringForKey:@"filter"] isEqualToString:@""])
            filtertext = [standardDefaults stringForKey:@"filter"];
        
        [task setCurrentDirectoryPath:laravelPath];
        task.launchPath = @"/usr/bin/php";
        task.arguments = @[@"artisan", @"route:list"];
        task.standardOutput = pipe;
        
        [task launch];
        
        NSData *data = [file readDataToEndOfFile];
        
        [file closeFile];
        [data writeToFile:[NSString stringWithFormat:@"%@/route.txt", laravelPath] atomically:YES];
        NSString *grepOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        //NSLog (@"Routes returned:\n%@", grepOutput);
        
        //loop through and generate Annotations

        NSMutableArray * fileLines = [[NSMutableArray alloc] initWithArray:[grepOutput componentsSeparatedByString:@"|"] copyItems: YES];
        int ln = 0;
        NSString *annotations = @"<?php;\n";
        annotations = [annotations stringByAppendingString:@"/**\n"];
        annotations = [annotations stringByAppendingString:@"* @SWG\\Swagger(\n"];
        annotations = [annotations stringByAppendingString:@"*   schemes={\"http\", \"https\"},\n"];
        annotations = [annotations stringByAppendingString:@"*   host=\"tiktiks.localhost\",\n"];
        annotations = [annotations stringByAppendingString:@"*   basePath=\"/api/\"\n"];
        annotations = [annotations stringByAppendingString:@"* )\n"];
        annotations = [annotations stringByAppendingString:@"*/\n\n"];
        
        annotations = [annotations stringByAppendingString:@"/**\n"];
        annotations = [annotations stringByAppendingString:@"* @SWG\\Info(title=\"API\", version=\"0.1\")\n"];
        annotations = [annotations stringByAppendingString:@"*/\n\n"];
        
        
        for (NSString *aline in fileLines) {
            ln++;
            //NSLog(@"ln%i:%@", ln, aline);
            if(ln > 10){ //skip header
                if ([aline rangeOfString:filtertext].location != NSNotFound)
                {
                    NSString *line = [aline stringByReplacingOccurrencesOfString:filtertext withString:@""];
                    
                    //Find All api header types
                    NSString *ops = @"GET|HEAD|POST|PUT|PATCH|DELETE";
                    NSInteger e = 0;
                    for(e=0;e<6;e++){
                        if([ops rangeOfString:trim(fileLines[ln-2-e])].location != NSNotFound ){
                            // Found api string append function
                            annotations = [annotations stringByAppendingString:@"/**\n"];
                            //Found an operation add Api Call and Associated Parameters
                            annotations = [annotations stringByAppendingString:[NSString stringWithFormat:@"* @SWG\\%@(\n", trim(fileLines[ln-2-e])]];
                            
                            NSURL *apiPath = [NSURL URLWithString:trim([line componentsSeparatedByString:@"{"][0])];
                            IFPrint(@"\nPath: \n\t%@\nParameters:\n", [apiPath path]);
                            
                            annotations = [annotations stringByAppendingString:[NSString stringWithFormat:@"*   path=\"%@\",\n", [apiPath path]]];
                            //get input parameters
                            NSArray * phpParts = [trim(fileLines[ln+1]) componentsSeparatedByString:@"@"];
                            
                            NSArray *params = processInputs(rootPath, [NSString stringWithFormat:@"%@.php",phpParts[0]], phpParts[1]);
                            for (NSString *par in params) {
                                IFPrint(@"\t %@\n", par);
                                annotations = [annotations stringByAppendingString:@"*     @SWG\\Parameter(\n"];
                                annotations = [annotations stringByAppendingString:[NSString stringWithFormat:@"*         description=\"%@\",\n", par]];
                                //annotations = [annotations stringByAppendingString:@"*         format=\"string\",\n"];
                                annotations = [annotations stringByAppendingString:@"*         in=\"formData\",\n"];
                                annotations = [annotations stringByAppendingString:[NSString stringWithFormat:@"*         name=\"%@\",\n", par]];
                                annotations = [annotations stringByAppendingString:@"*         required=false,\n"];
                                annotations = [annotations stringByAppendingString:@"*         type=\"string\"\n"];
                                annotations = [annotations stringByAppendingString:@"*     ),\n"];
                            }
                            
                            
                            annotations = [annotations stringByAppendingString:@"produces={\"application/json\", \"application/xml\", \"text/xml\", \"text/html\"},\n"];
                            NSArray *pbreak = [line componentsSeparatedByString:@"/"];
                            annotations = [annotations stringByAppendingString:[NSString stringWithFormat:@"*   summary=\"%@\",\n", trim([pbreak objectAtIndex:pbreak.count-1])]];
                            
                            annotations = [annotations stringByAppendingString:@"*   @SWG\\Response(\n"];
                            annotations = [annotations stringByAppendingString:@"*     response=200,\n"];
                            annotations = [annotations stringByAppendingString:[NSString stringWithFormat:@"*     description=\"%@\"\n", trim([pbreak objectAtIndex:pbreak.count-1])]];
                            annotations = [annotations stringByAppendingString:@"*   ),\n"];
                            
                            annotations = [annotations stringByAppendingString:@"*   @SWG\\Response(\n"];
                            annotations = [annotations stringByAppendingString:@"*     response=\"default\",\n"];
                            annotations = [annotations stringByAppendingString:@"*     description=\"an \"\"unexpected"" error\"\n"];
                            annotations = [annotations stringByAppendingString:@"*   )\n"];
                            annotations = [annotations stringByAppendingString:@"* )\n"];
                            annotations = [annotations stringByAppendingString:@"*/\n"];
                        }
                    }
                    
                    
                    
                }
            }
        }
        //getPaths(rootPath);
        [annotations writeToFile:[NSString stringWithFormat:@"%@/annotations.php", rootPath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
    }
    
    return 0;
}

