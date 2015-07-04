#import "NYPLConfiguration.h"
#import "NYPLReloadView.h"
#import "NYPLRemoteViewController.h"
#import "UIView+NYPLViewAdditions.h"

@interface NYPLRemoteViewController () <NSURLConnectionDataDelegate>

@property (nonatomic) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic) NSURLConnection *connection;
@property (nonatomic) NSMutableData *data;
@property (nonatomic, strong)
  UIViewController *(^handler)(NYPLRemoteViewController *remoteViewController, NSData *data);
@property (nonatomic) NYPLReloadView *reloadView;

@end

@implementation NYPLRemoteViewController

- (instancetype)initWithURL:(NSURL *const)URL
          completionHandler:(UIViewController *(^ const)
                             (NYPLRemoteViewController *remoteViewController,
                              NSData *data))handler
{
  self = [super init];
  if(!self) return nil;
  
  if(!handler) {
    @throw NSInvalidArgumentException;
  }
  
  self.handler = handler;
  self.URL = URL;
  
  return self;
}

- (void)load
{
  if(self.childViewControllers.count > 0) {
    UIViewController *const childViewController = self.childViewControllers[0];
    [childViewController willMoveToParentViewController:nil];
    [childViewController.view removeFromSuperview];
    [childViewController removeFromParentViewController];
    [childViewController didMoveToParentViewController:nil];
    NSAssert(self.childViewControllers.count == 0, @"No child view controllers remain.");
  }
  
  [self.connection cancel];
  
  NSURLRequest *const request = [NSURLRequest requestWithURL:self.URL
                                                 cachePolicy:NSURLRequestUseProtocolCachePolicy
                                             timeoutInterval:5.0];
  
  self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
  self.data = [NSMutableData data];
  
  [self.activityIndicatorView startAnimating];
  
  [self.connection start];
}

#pragma mark UIViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.view.backgroundColor = [NYPLConfiguration backgroundColor];
  
  self.activityIndicatorView = [[UIActivityIndicatorView alloc]
                                initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
  [self.view addSubview:self.activityIndicatorView];
  
  // We always nil out the connection when not in use so this is reliable.
  if(self.connection) {
    [self.activityIndicatorView startAnimating];
  }
  
  __weak NYPLRemoteViewController *weakSelf = self;
  self.reloadView = [[NYPLReloadView alloc] init];
  self.reloadView.handler = ^{
    weakSelf.reloadView.hidden = YES;
    [weakSelf load];
  };
  self.reloadView.hidden = YES;
  [self.view addSubview:self.reloadView];
}

- (void)viewWillLayoutSubviews
{
  [self.activityIndicatorView centerInSuperview];
  [self.activityIndicatorView integralizeFrame];
  
  [self.reloadView centerInSuperview];
  [self.reloadView integralizeFrame];
}

#pragma mark NSURLConnectionDataDelegate

- (void)connection:(__attribute__((unused)) NSURLConnection *)connection
    didReceiveData:(NSData *const)data
{
  [self.data appendData:data];
}

- (void)connectionDidFinishLoading:(__attribute__((unused)) NSURLConnection *)connection
{
  [self.activityIndicatorView stopAnimating];
  
  UIViewController *const viewController = self.handler(self, self.data);
  
  if(viewController) {
    [viewController willMoveToParentViewController:self];
    [self addChildViewController:viewController];
    viewController.view.frame = self.view.bounds;
    [self.view addSubview:viewController.view];
    if(viewController.navigationItem.rightBarButtonItems) {
      self.navigationItem.rightBarButtonItems = viewController.navigationItem.rightBarButtonItems;
    }
    if(viewController.navigationItem.leftBarButtonItems) {
      self.navigationItem.leftBarButtonItems = viewController.navigationItem.leftBarButtonItems;
    }
    if(viewController.navigationItem.title) {
      self.navigationItem.title = viewController.navigationItem.title;
    }
    [viewController didMoveToParentViewController:self];
  } else {
    self.reloadView.hidden = NO;
  }
  
  self.connection = nil;
  self.data = nil;
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(__attribute__((unused)) NSURLConnection *)connection
  didFailWithError:(__attribute__((unused)) NSError *)error
{
  [self.activityIndicatorView stopAnimating];
  
  self.reloadView.hidden = NO;
  
  self.connection = nil;
  self.data = nil;
}

@end
