//
//  ViewController.m
//  IPAddressIPV6
//
//  Created by Haider Shahzad on 29/01/2021.
//

#import "ViewController.h"

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
//#define IOS_VPN       @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

#import <netdb.h>
#import <arpa/inet.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSLog(@"getIPAddress %@", [self getIPAddress]);
    NSLog(@"getIPAddressForHost %@", [ViewController getIPAddressForHost:@"www.google.com"]);
    NSLog(@"resolveHostForURL %@", [self resolveHost:@"www.google.com"]);
    
    
}

- (NSString *)getIPAddress {
    
    NSDictionary *dict = [self getIPAddresses];
    if ([dict objectForKey:@"en0/ipv4"]) {
        NSLog(@"You are connected to wifi network: %@",[dict objectForKey:@"en0/ipv4"]);
        return [dict objectForKey:@"en0/ipv4"];
    } else if ([dict objectForKey:@"pdp_ip0/ipv4"]) {
        NSLog(@"You are connected to mobile network: %@",[dict objectForKey:@"pdp_ip0/ipv4"]);
        return [dict objectForKey:@"pdp_ip0/ipv4"];
    }
    return @"error";
}


- (NSString *)getIPAddress:(BOOL)preferIPv4
{
    NSArray *searchArray = preferIPv4 ?
    @[IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self getIPAddresses];
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
        address = addresses[key];
        if(address) *stop = YES;
    } ];
    return address ? address : @"0.0.0.0";
}


- (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}


+ (NSString*) getIPAddressForHost: (NSString*) theHost {
    if(theHost == nil) { return nil; }
    struct hostent *host = gethostbyname([theHost UTF8String]);
    if (host == NULL) {
        herror("resolv");
        return NULL;
    }
    struct in_addr **list = (struct in_addr **)host->h_addr_list;
    NSString *addressString = [NSString stringWithCString:inet_ntoa(*list[0]) encoding: NSUTF8StringEncoding];
    return addressString;
}

- (NSString*)resolveHost:(NSString *)hostname {
    Boolean result = false;
    CFHostRef hostRef;
    CFArrayRef addresses;
    NSString *ipAddress = nil;
    hostRef = CFHostCreateWithName(kCFAllocatorDefault, (__bridge
                                                         CFStringRef)hostname);
    CFStreamError *error = NULL;
    if (hostRef) {
        result = CFHostStartInfoResolution(hostRef, kCFHostAddresses, error);
        if (result) {
            addresses = CFHostGetAddressing(hostRef, &result);
        }
    }
    if (result) {
        CFIndex index = 0;
        CFDataRef ref = (CFDataRef) CFArrayGetValueAtIndex(addresses, index);
        
        int port=0;
        struct sockaddr *addressGeneric;
        
        NSData *myData = (__bridge NSData *)ref;
        addressGeneric = (struct sockaddr *)[myData bytes];
        
        switch (addressGeneric->sa_family) {
            case AF_INET: {
                struct sockaddr_in *ip4;
                char dest[INET_ADDRSTRLEN];
                ip4 = (struct sockaddr_in *)[myData bytes];
                port = ntohs(ip4->sin_port);
                ipAddress = [NSString stringWithFormat:@"%s", inet_ntop(AF_INET, &ip4->sin_addr, dest, sizeof dest)];
            }
                break;
                
            case AF_INET6: {
                struct sockaddr_in6 *ip6;
                char dest[INET6_ADDRSTRLEN];
                ip6 = (struct sockaddr_in6 *)[myData bytes];
                port = ntohs(ip6->sin6_port);
                ipAddress = [NSString stringWithFormat:@"%s", inet_ntop(AF_INET6, &ip6->sin6_addr, dest, sizeof dest)];
            }
                break;
            default:
                ipAddress = nil;
                break;
        }
    }
    
    return ipAddress;
}




@end
