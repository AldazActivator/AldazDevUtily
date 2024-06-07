//  Created by iAldaz on 05/06/24.
//
/*     _    _     _           ____              */
/*    / \  | | __| | __ _ ___|  _ \  _____   __ */
/*   / _ \ | |/ _` |/ _` |_  / | | |/ _ \ \ / / */
/*  / ___ \| | (_| | (_| |/ /| |_| |  __/\ V /  */
/* /_/   \_\_|\__,_|\__,_/___|____/ \___| \_/   */

#import <Foundation/Foundation.h>
#import <unistd.h>
#import <spawn.h>
#import <sys/wait.h>
#import "./NSTask.h"

@interface JailbreakHelper : NSObject
+ (BOOL)runScript:(NSString *)command type:(NSString *)route;
//+ (void)runCmdPrintf:(NSString *)command;
@end

@implementation JailbreakHelper

+ (BOOL)runScript:(NSString *)command type:(NSString *)route {
    // Configurar las variables de entorno para asegurarse de que las bibliotecas se encuentren correctamente
    setenv("DYLD_LIBRARY_PATH", "/System/Library/Frameworks/Foundation.framework", 1);
    setenv("DYLD_FRAMEWORK_PATH", "/System/Library/Frameworks/Foundation.framework", 1);

    // Preparar los argumentos para posix_spawn
    const char *argv[] = {route.UTF8String, "-c", command.UTF8String, NULL};
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);

    // Configurar los pipes para capturar la salida
    int pipefd[2];
    if (pipe(pipefd) == -1) {
        perror("pipe");
        return NO;
    }
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[1]);

    pid_t pid;
    int status;
    if (posix_spawn(&pid, route.UTF8String, &actions, NULL, (char *const *)argv, NULL) == 0) {
        close(pipefd[1]); // Cerrar la escritura del pipe
        char buffer[4096];
        ssize_t count;
        NSMutableString *output = [NSMutableString string];
        while ((count = read(pipefd[0], buffer, sizeof(buffer))) > 0) {
            [output appendString:[[NSString alloc] initWithBytes:buffer length:count encoding:NSUTF8StringEncoding]];
        }
        close(pipefd[0]); // Cerrar la lectura del pipe
        waitpid(pid, &status, 0); // Esperar a que el proceso hijo termine
        printf("%s\n", output.UTF8String);
    } else {
        printf("Failed to spawn process\n");
        return NO;
    }

    posix_spawn_file_actions_destroy(&actions);

    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}


@end

@interface EraseManager : NSObject
- (void)runErase:(NSString *)Type;
- (void)runBlockOTA:(NSString *)Type;
- (void)UnloadMobileactivationd:(NSString *)Type;
- (void)loadMobileactivationd:(NSString *)Type;
- (void)rebootAllLaunchDaemons:(NSString *)Type;
- (void)GetGeneralLog:(NSString *)Type;
- (void)rebootDevice:(NSString *)Type;

@end

@implementation EraseManager

- (void)runErase:(NSString *)Type {
    NSArray *daemonsToLoad = @[
        @"com.apple.CommCenterRootHelper.plist",
        @"com.apple.CommCenterMobileHelper.plist",
        @"com.apple.mobile.obliteration.plist",
        @"com.apple.devicedataresetd.plist",
        @"com.apple.backboardd.plist",
        @"com.apple.runningboardd.plist"
    ];

    for (NSString *daemon in daemonsToLoad) {
        NSString *command = [NSString stringWithFormat:@"launchctl load -w -F /System/Library/LaunchDaemons/%@", daemon];
        [JailbreakHelper runScript:command type:Type];
    }

    [JailbreakHelper runScript:@"mv -f $(find /private/preboot/*/usr/local -iname Baseband2) $(find /private/preboot/*/usr/local -iname Baseband2)/../Baseband" type:Type];
    [JailbreakHelper runScript:@"killall -9 SpringBoard mobileactivationd" type:Type];
    [JailbreakHelper runScript:@"/usr/sbin/nvram oblit-inprogress=5 sync" type:Type];
    [JailbreakHelper runScript:@"/usr/sbin/nvram oblit-inprogress=5" type:Type];
    [JailbreakHelper runScript:@"launchctl reboot" type:Type];
}

- (void)runBlockOTA: (NSString *)Type {
    NSArray *daemonsToLoad = @[
        @"com.apple.softwareupdateservicesd.plist",
        @"com.apple.mobile.softwareupdated.plist",
        @"com.apple.OTATaskingAgent.plist",
        @"com.apple.mobile.obliteration.plist",
    ];

    for (NSString *daemon in daemonsToLoad) {
        NSString *command = [NSString stringWithFormat:@"launchctl unload -F -w /System/Library/LaunchDaemons/%@", daemon];
        [JailbreakHelper runScript:command type:Type];
    }

    [JailbreakHelper runScript:@"killall -9 backboardd" type:Type];
}

- (void)UnloadMobileactivationd: (NSString *)Type {
    [JailbreakHelper runScript:@"launchctl unload /System/Library/LaunchDaemons/com.apple.mobileactivationd.plist" type:Type];
    [JailbreakHelper runScript:@"launchctl stop com.apple.mobileactivationd" type:Type];
}

- (void)loadMobileactivationd: (NSString *)Type{
    [JailbreakHelper runScript:@"launchctl load /System/Library/LaunchDaemons/com.apple.mobileactivationd.plist" type:Type];
    [JailbreakHelper runScript:@"launchctl start com.apple.mobileactivationd" type:Type];
}

- (void)rebootAllLaunchDaemons: (NSString *)Type {
    
    [JailbreakHelper runScript:@"mv -f $(find /private/preboot/*/usr/local -iname Baseband2) $(find /private/preboot/*/usr/local -iname Baseband2)/../Baseband" type:Type];
    
    [JailbreakHelper runScript:@"launchctl unload -F -w /System/Library/LaunchDaemons/* && launchctl load -F -w /System/Library/LaunchDaemons/*" type:Type];
}

- (void)rebootDevice: (NSString *)Type {
    [JailbreakHelper runScript:@"launchctl reboot" type:Type];
}

- (void)GetGeneralLog: (NSString *)Type{
    //[JailbreakHelper runScript:@"cat /var/logs/AppleSupport/general.log"];
    [JailbreakHelper runScript:@"cat /var/logs/AppleSupport/general.log" type:Type];

}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        setenv("DYLD_LIBRARY_PATH", "/System/Library/Frameworks/Foundation.framework", 1);
        setenv("DYLD_FRAMEWORK_PATH", "/System/Library/Frameworks/Foundation.framework", 1);
        
        if (argc < 4) {
            
            printf("Usage: ./AldazDev -command <key> <mode_jb>\n\n");
            printf("0x8a5fbdb4f16624ecb5 - Erase Device\n");
            printf("0x89o5a - BlockOTA\n");
            printf("09xt0X - Unload MobileActivationd\n");
            printf("09xGA - Load MobileActivationd\n");
            printf("07x89Zy - Reboot LaunchDaemons\n");
            printf("reboot - Reboot device\n\n");
            printf("Example: ./AldazDev -command 09xt0X Rootless\n");

            return 1;
        }
        
        NSString *mode = [NSString stringWithUTF8String:argv[3]];
        
        NSString* RouteSh;
        
        if([mode isEqualToString:@"Rootless"]){
            RouteSh = @"/var/jb/bin/sh";
        }
        else{
            RouteSh = @"/bin/sh";
        }
        
        NSString *action = [NSString stringWithUTF8String:argv[2]];
        
        
        EraseManager *eraseManager = [[EraseManager alloc] init];

        if ([action isEqualToString:@"0x0"]) {
            
            NSString *command = @"cd /var/ && echo 'Hello im tested!' > /hello.txt";
            BOOL success = [JailbreakHelper runScript:command type:RouteSh];
            
            NSLog(@"Script run %@", success ? @"successfully" : @"with errors");
            
        } else if ([action isEqualToString:@"0x8a5fbdb4f16624ecb5"]) {
            [eraseManager runErase: RouteSh];
        }
        else if ([action isEqualToString:@"0x89o5a"]) {
            [eraseManager runBlockOTA: RouteSh];
        }
        else if ([action isEqualToString:@"09xt0X"]) {
            [eraseManager UnloadMobileactivationd: RouteSh];
        }
        else if ([action isEqualToString:@"09xGA"]) {
            [eraseManager loadMobileactivationd: RouteSh];
        }
        else if ([action isEqualToString:@"07x89Zy"]) {
            [eraseManager rebootAllLaunchDaemons: RouteSh];
        }
        else if ([action isEqualToString:@"reboot"]) {
            [eraseManager rebootDevice: RouteSh];
        }
        else {
            [eraseManager GetGeneralLog: RouteSh];
        }
    }
    return 0;
}
