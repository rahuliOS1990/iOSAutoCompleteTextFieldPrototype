

#define kHTAutoCompleteButtonWidth  30


#import "LSAutoCompleteTextField.h"

#import "NSString+Levenshtein.h"
#import <QuartzCore/QuartzCore.h>


static NSString *kSortInputStringKey = @"sortInputString";
static NSString *kSortEditDistancesKey = @"editDistances";
static NSString *kSortObjectKey = @"sortObject";
static NSString *kKeyboardAccessoryInputKeyPath = @"autoCompleteTableAppearsAsKeyboardAccessory";
const NSTimeInterval DefaultAutoCompleteRequestDelay = 0.1;

@interface LSAutoCompleteSortOperation: NSOperation
@property (strong) NSString *incompleteString;
@property (strong) NSArray *possibleCompletions;
@property (strong) id <LSAutoCompleteSortOperationDelegate> delegate;
@property (strong) NSDictionary *boldTextAttributes;
@property (strong) NSDictionary *regularTextAttributes;

- (id)initWithDelegate:(id<LSAutoCompleteSortOperationDelegate>)aDelegate
      incompleteString:(NSString *)string
   possibleCompletions:(NSArray *)possibleStrings;

- (NSArray *)sortedCompletionsForString:(NSString *)inputString
                    withPossibleStrings:(NSArray *)possibleTerms;
@end

static NSString *kFetchedTermsKey = @"terms";
static NSString *kFetchedStringKey = @"fetchInputString";
@interface LSAutoCompleteFetchOperation: NSOperation
@property (strong) NSString *incompleteString;
@property (strong) LSAutoCompleteTextField *textField;
@property (strong) id <LSAutoCompleteFetchOperationDelegate> delegate;
@property (strong) id <LSAutoCompleteTextFieldDataSource> dataSource;

- (id)initWithDelegate:(id<LSAutoCompleteFetchOperationDelegate>)aDelegate
 completionsDataSource:(id<LSAutoCompleteTextFieldDataSource>)aDataSource
 autoCompleteTextField:(LSAutoCompleteTextField *)aTextField;

@end


static NSString *kBorderStyleKeyPath = @"borderStyle";
static NSString *kAutoCompleteTableViewHiddenKeyPath = @"autoCompleteTableView.hidden";
static NSString *kBackgroundColorKeyPath = @"backgroundColor";
static NSString *kDefaultAutoCompleteCellIdentifier = @"_DefaultAutoCompleteCellIdentifier";

@interface LSAutoCompleteTextField ()

@property (strong, readwrite) UITableView *autoCompleteTableView;
@property (strong) NSArray *autoCompleteSuggestions;
@property (strong) NSOperationQueue *autoCompleteSortQueue;
@property (strong) NSOperationQueue *autoCompleteFetchQueue;
@property (strong) NSString *reuseIdentifier;
@property (assign) CGColorRef originalShadowColor;
@property (assign) CGSize originalShadowOffset;
@property (assign) CGFloat originalShadowOpacity;


/// Edited by Rahul

/*
 * Configure text field appearance
 */
@property (nonatomic, strong) UILabel *autocompleteLabel;
- (void)setFont:(UIFont *)font;
@property (nonatomic, assign) CGPoint autocompleteTextOffset;
@property (nonatomic, strong) NSString *autocompleteString;
@property (nonatomic, strong) UIButton *autocompleteButton;
@property (nonatomic, assign) BOOL autocompleteDisabled;
@property (nonatomic, assign) BOOL ignoreCase;
@property (nonatomic, assign) BOOL showAutocompleteButton;

@end



@implementation LSAutoCompleteTextField

#pragma mark - Init

- (id)init
{
    self = [super init];
    if (self) {
        [self initialize];
         [self setupAutocompleteTextField];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
        [self setupAutocompleteTextField];

    }
    return self;
}




- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        
        [self initialize];
    }
    return self;
}

- (void)dealloc
{
    [self closeAutoCompleteTableView];
    [self stopObservingKeyPathsAndNotifications];
}

- (void)initialize
{
   
    [self beginObservingKeyPathsAndNotifications];
    
    [self setDefaultValuesForVariables];
    
    UITableView *newTableView = [self newAutoCompleteTableViewForTextField:self];
    [self setAutoCompleteTableView:newTableView];
    
    [self styleAutoCompleteTableForBorderStyle:self.borderStyle];
}


#pragma mark - Notifications and KVO

- (void)beginObservingKeyPathsAndNotifications
{
    [self addObserver:self
           forKeyPath:kBorderStyleKeyPath
              options:NSKeyValueObservingOptionNew context:nil];
    
    
    [self addObserver:self
           forKeyPath:kAutoCompleteTableViewHiddenKeyPath
              options:NSKeyValueObservingOptionNew context:nil];
    
    
    [self addObserver:self
           forKeyPath:kBackgroundColorKeyPath
              options:NSKeyValueObservingOptionNew context:nil];
    
    [self addObserver:self
           forKeyPath:kKeyboardAccessoryInputKeyPath
              options:NSKeyValueObservingOptionNew context:nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textFieldDidChangeWithNotification:)
                                                 name:UITextFieldTextDidChangeNotification object:self];
}

- (void)stopObservingKeyPathsAndNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self removeObserver:self forKeyPath:kBorderStyleKeyPath];
    [self removeObserver:self forKeyPath:kAutoCompleteTableViewHiddenKeyPath];
    [self removeObserver:self forKeyPath:kBackgroundColorKeyPath];
    [self removeObserver:self forKeyPath:kKeyboardAccessoryInputKeyPath];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:self];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:kBorderStyleKeyPath]) {
        [self styleAutoCompleteTableForBorderStyle:self.borderStyle];
    } else if ([keyPath isEqualToString:kAutoCompleteTableViewHiddenKeyPath]) {
        if(self.autoCompleteTableView.hidden){
            [self closeAutoCompleteTableView];
        } else {
            [self.autoCompleteTableView reloadData];
        }
    } else if ([keyPath isEqualToString:kBackgroundColorKeyPath]){
        [self styleAutoCompleteTableForBorderStyle:self.borderStyle];
    } else if ([keyPath isEqualToString:kKeyboardAccessoryInputKeyPath]){
        if(self.autoCompleteTableAppearsAsKeyboardAccessory){
            [self setAutoCompleteTableForKeyboardAppearance];
        } else {
            [self setAutoCompleteTableForDropDownAppearance];
        }
    }
}

#pragma mark - TableView Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows = [self.autoCompleteSuggestions count];
    [self expandAutoCompleteTableViewForNumberOfRows:numberOfRows];
    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    NSString *cellIdentifier = kDefaultAutoCompleteCellIdentifier;
    
    if(!self.reuseIdentifier){
        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil) {
            cell = [self autoCompleteTableViewCellWithReuseIdentifier:cellIdentifier];
        }
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:self.reuseIdentifier];
    }
    NSAssert(cell, @"Unable to create cell for autocomplete table");
    
    
    id autoCompleteObject = self.autoCompleteSuggestions[indexPath.row];
    NSString *suggestedString;
    if([autoCompleteObject isKindOfClass:[NSString class]]){
        suggestedString = (NSString *)autoCompleteObject;
    }
    else {
        NSAssert(0, @"Autocomplete suggestions must either be NSString or objects conforming to the LSAutoCompletionObject protocol.");
    }
    
    
    [self configureCell:cell atIndexPath:indexPath withAutoCompleteString:suggestedString];
    
    
    return cell;
}

- (UITableViewCell *)autoCompleteTableViewCellWithReuseIdentifier:(NSString *)identifier
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                   reuseIdentifier:identifier];
    [cell setBackgroundColor:[UIColor clearColor]];
    [cell.textLabel setTextColor:self.textColor];
    [cell.textLabel setFont:self.font];
    return cell;
}

+ (NSString *) accessibilityLabelForIndexPath:(NSIndexPath *)indexPath
{
    return [NSString stringWithFormat:@"{%d,%d}",indexPath.section,indexPath.row];
}

- (void)configureCell:(UITableViewCell *)cell
          atIndexPath:(NSIndexPath *)indexPath
withAutoCompleteString:(NSString *)string
{
    
    NSAttributedString *boldedString = nil;
    BOOL attributedTextSupport = [cell.textLabel respondsToSelector:@selector(setAttributedText:)];
    if(attributedTextSupport && self.applyBoldEffectToAutoCompleteSuggestions){
        NSRange boldedRange = [string rangeOfString:self.text options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch];
        boldedString = [self boldedString:string withRange:boldedRange];
    }
    
    id autoCompleteObject = self.autoCompleteSuggestions[indexPath.row];
  
    
    if([self.autoCompleteDelegate respondsToSelector:@selector(autoCompleteTextField:shouldConfigureCell:withAutoCompleteString:withAttributedString:forRowAtIndexPath:)])
    {
        if(![self.autoCompleteDelegate autoCompleteTextField:self shouldConfigureCell:cell withAutoCompleteString:string withAttributedString:boldedString forRowAtIndexPath:indexPath])
        {
            return;
        }
    }
    
    [cell.textLabel setTextColor:self.textColor];
    
    if(boldedString){
        if ([cell.textLabel respondsToSelector:@selector(setAttributedText:)]) {
            [cell.textLabel setAttributedText:boldedString];
        } else{
            [cell.textLabel setText:string];
            [cell.textLabel setFont:[UIFont fontWithName:self.font.fontName size:self.autoCompleteFontSize]];
        }
    
    } else {
        [cell.textLabel setText:string];
        [cell.textLabel setFont:[UIFont fontWithName:self.font.fontName size:self.autoCompleteFontSize]];
    }
    
    cell.accessibilityLabel = [[self class] accessibilityLabelForIndexPath:indexPath];
    
    if(self.autoCompleteTableCellTextColor){
        [cell.textLabel setTextColor:self.autoCompleteTableCellTextColor];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [cell setBackgroundColor:self.autoCompleteTableCellBackgroundColor];
}

#pragma mark - TableView Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.autoCompleteRowHeight;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(!self.autoCompleteTableAppearsAsKeyboardAccessory){
        [self closeAutoCompleteTableView];
    }
    
    UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *autoCompleteString = selectedCell.textLabel.text;
    self.text = autoCompleteString;
   
    self.autocompleteDisabled=YES;
    self.autocompleteLabel.hidden=YES;
  
    if([self.autoCompleteDelegate respondsToSelector:
        @selector(autoCompleteTextField:didSelectAutoCompleteString:forRowAtIndexPath:)]){
        
        [self.autoCompleteDelegate autoCompleteTextField:self
                             didSelectAutoCompleteString:autoCompleteString
                                       forRowAtIndexPath:indexPath];
    }
    
    [self finishedSearching];
}

#pragma mark - AutoComplete Sort Operation Delegate


- (void)autoCompleteTermsDidSort:(NSArray *)completions
{
    [self setAutoCompleteSuggestions:completions];
    [self.autoCompleteTableView reloadData];

    if ([self.autoCompleteDelegate
         respondsToSelector:@selector(autoCompleteTextField:didChangeNumberOfSuggestions:)]) {
        [self.autoCompleteDelegate autoCompleteTextField:self
                            didChangeNumberOfSuggestions:self.autoCompleteSuggestions.count];
    }
}

#pragma mark - AutoComplete Fetch Operation Delegate

- (void)autoCompleteTermsDidFetch:(NSDictionary *)fetchInfo
{
    NSString *inputString = fetchInfo[kFetchedStringKey];
    NSArray *completions = fetchInfo[kFetchedTermsKey];
    
    [self.autoCompleteSortQueue cancelAllOperations];
    
    if(self.sortAutoCompleteSuggestionsByClosestMatch){
        LSAutoCompleteSortOperation *operation =
        [[LSAutoCompleteSortOperation alloc] initWithDelegate:self
                                              incompleteString:inputString
                                           possibleCompletions:completions];
        [self.autoCompleteSortQueue addOperation:operation];
    } else {
        [self autoCompleteTermsDidSort:completions];
    }
}

#pragma mark - Events

- (void)textFieldDidChangeWithNotification:(NSNotification *)aNotification
{
    if(aNotification.object == self){
      
        self.autocompleteDisabled=NO;
        self.autocompleteLabel.hidden=NO;

        [self reloadData];
       
        if (self.autoCompleteSuggestions.count==0) {
           
        [self performSelector:@selector(refreshAutocompleteText) withObject:nil afterDelay:.3];
        }
        else
        {
           
           [self refreshAutocompleteText];
        }
        
    
    }
}

- (BOOL)becomeFirstResponder
{
    // This is necessary because the textfield avoids tapping the autocomplete Button
    [self bringSubviewToFront:self.autocompleteButton];
    if (!self.autocompleteDisabled)
    {
        if ([self clearsOnBeginEditing])
        {
            self.autocompleteLabel.text = @"";
        }
        
        self.autocompleteLabel.hidden = NO;
    }
    

    
    [self saveCurrentShadowProperties];
    
    if(self.showAutoCompleteTableWhenEditingBegins ||
       self.autoCompleteTableAppearsAsKeyboardAccessory){
        [self fetchAutoCompleteSuggestions];
    }
    
    return [super becomeFirstResponder];
}

- (void) finishedSearching
{
    if (self.shouldResignFirstResponderFromKeyboardAfterSelectionOfAutoCompleteRows) {
        [self resignFirstResponder];
    }
}

- (BOOL)resignFirstResponder
{
    if (!self.autocompleteDisabled)
    {
        self.autocompleteLabel.hidden = YES;
        
        if ([self commitAutocompleteText]) {
            // Only notify if committing autocomplete actually changed the text.
            
            
            // This is necessary because committing the autocomplete text changes the text field's text, but for some reason UITextField doesn't post the UITextFieldTextDidChangeNotification notification on its own
            [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification
                                                                object:self];
        }
    }

    
    [self restoreOriginalShadowProperties];
    if(!self.autoCompleteTableAppearsAsKeyboardAccessory){
        [self closeAutoCompleteTableView];
    }
    return [super resignFirstResponder];
}



#pragma mark - Open/Close Actions

- (void)expandAutoCompleteTableViewForNumberOfRows:(NSInteger)numberOfRows
{
    NSAssert(numberOfRows >= 0,
             @"Number of rows given for auto complete table was negative, this is impossible.");
    
    if(!self.isFirstResponder){
        return;
    }
    
    if(self.autoCompleteTableAppearsAsKeyboardAccessory){
        [self expandKeyboardAutoCompleteTableForNumberOfRows:numberOfRows];
    } else {
        [self expandDropDownAutoCompleteTableForNumberOfRows:numberOfRows];
    }
    
}

- (void)expandKeyboardAutoCompleteTableForNumberOfRows:(NSInteger)numberOfRows
{
    if(numberOfRows && (self.autoCompleteTableViewHidden == NO)){
        [self.autoCompleteTableView setAlpha:1];
    } else {
        [self.autoCompleteTableView setAlpha:0];
    }
}

- (void)expandDropDownAutoCompleteTableForNumberOfRows:(NSInteger)numberOfRows
{
    [self resetDropDownAutoCompleteTableFrameForNumberOfRows:numberOfRows];
    
    
    if(numberOfRows && (self.autoCompleteTableViewHidden == NO)){
        [self.autoCompleteTableView setAlpha:1];
        
        if(!self.autoCompleteTableView.superview){
            if([self.autoCompleteDelegate
                respondsToSelector:@selector(autoCompleteTextField:willShowAutoCompleteTableView:)]){
                [self.autoCompleteDelegate autoCompleteTextField:self
                                   willShowAutoCompleteTableView:self.autoCompleteTableView];
            }
        }
        
        [self.superview bringSubviewToFront:self];
        UIView *rootView = [self.window.subviews objectAtIndex:0];
        [rootView insertSubview:self.autoCompleteTableView
                         belowSubview:self];
        [self.autoCompleteTableView setUserInteractionEnabled:YES];
        if(self.showTextFieldDropShadowWhenAutoCompleteTableIsOpen){
            [self.layer setShadowColor:[[UIColor blackColor] CGColor]];
            [self.layer setShadowOffset:CGSizeMake(0, 1)];
            [self.layer setShadowOpacity:0.35];
        }
    } else {
        [self closeAutoCompleteTableView];
        [self restoreOriginalShadowProperties];
        [self.autoCompleteTableView.layer setShadowOpacity:0.0];
    }
}


- (void)closeAutoCompleteTableView
{
    [self.autoCompleteTableView removeFromSuperview];
    [self restoreOriginalShadowProperties];
}


#pragma mark - Setters



- (void)setDefaultValuesForVariables
{
    [self setClipsToBounds:NO];
    [self setAutoCompleteFetchRequestDelay:DefaultAutoCompleteRequestDelay];
    [self setSortAutoCompleteSuggestionsByClosestMatch:YES];
    [self setApplyBoldEffectToAutoCompleteSuggestions:YES];
    [self setShowTextFieldDropShadowWhenAutoCompleteTableIsOpen:YES];
    [self setShouldResignFirstResponderFromKeyboardAfterSelectionOfAutoCompleteRows:YES];
    [self setAutoCompleteRowHeight:40];
    [self setAutoCompleteFontSize:13];
    [self setMaximumNumberOfAutoCompleteRows:3];
    [self setPartOfAutoCompleteRowHeightToCut:0.5f];
    
    [self setAutoCompleteTableCellBackgroundColor:[UIColor clearColor]];
    
    UIFont *regularFont = [UIFont systemFontOfSize:13];
    [self setAutoCompleteRegularFontName:regularFont.fontName];
    
    UIFont *boldFont = [UIFont boldSystemFontOfSize:13];
    [self setAutoCompleteBoldFontName:boldFont.fontName];
    
    [self setAutoCompleteSuggestions:[NSMutableArray array]];
    
    [self setAutoCompleteSortQueue:[NSOperationQueue new]];
    self.autoCompleteSortQueue.name = [NSString stringWithFormat:@"Autocomplete Queue %i", arc4random()];
    
    [self setAutoCompleteFetchQueue:[NSOperationQueue new]];
    self.autoCompleteFetchQueue.name = [NSString stringWithFormat:@"Fetch Queue %i", arc4random()];
}


- (void)setAutoCompleteTableForKeyboardAppearance
{
    [self resetKeyboardAutoCompleteTableFrameForNumberOfRows:self.maximumNumberOfAutoCompleteRows];
    [self.autoCompleteTableView setContentInset:UIEdgeInsetsZero];
    [self.autoCompleteTableView setScrollIndicatorInsets:UIEdgeInsetsZero];
    [self setInputAccessoryView:self.autoCompleteTableView];
}

- (void)setAutoCompleteTableForDropDownAppearance
{
    [self resetDropDownAutoCompleteTableFrameForNumberOfRows:self.maximumNumberOfAutoCompleteRows];
    [self.autoCompleteTableView setContentInset:self.autoCompleteContentInsets];
    [self.autoCompleteTableView setScrollIndicatorInsets:self.autoCompleteScrollIndicatorInsets];
    [self setInputAccessoryView:nil];
}



- (void)setAutoCompleteTableViewHidden:(BOOL)autoCompleteTableViewHidden
{
    [self.autoCompleteTableView setHidden:autoCompleteTableViewHidden];
}

- (void)setAutoCompleteTableBackgroundColor:(UIColor *)autoCompleteTableBackgroundColor
{
    [self.autoCompleteTableView setBackgroundColor:autoCompleteTableBackgroundColor];
    _autoCompleteTableBackgroundColor = autoCompleteTableBackgroundColor;
}

- (void)setAutoCompleteTableBorderWidth:(CGFloat)autoCompleteTableBorderWidth
{
    [self.autoCompleteTableView.layer setBorderWidth:autoCompleteTableBorderWidth];
    _autoCompleteTableBorderWidth = autoCompleteTableBorderWidth;
}

- (void)setAutoCompleteTableBorderColor:(UIColor *)autoCompleteTableBorderColor
{
    [self.autoCompleteTableView.layer setBorderColor:[autoCompleteTableBorderColor CGColor]];
    _autoCompleteTableBorderColor = autoCompleteTableBorderColor;
}

- (void)setAutoCompleteContentInsets:(UIEdgeInsets)autoCompleteContentInsets
{
    [self.autoCompleteTableView setContentInset:autoCompleteContentInsets];
    _autoCompleteContentInsets = autoCompleteContentInsets;
}

- (void)setAutoCompleteScrollIndicatorInsets:(UIEdgeInsets)autoCompleteScrollIndicatorInsets
{
    [self.autoCompleteTableView setScrollIndicatorInsets:autoCompleteScrollIndicatorInsets];
    _autoCompleteScrollIndicatorInsets = autoCompleteScrollIndicatorInsets;
}

- (void)resetKeyboardAutoCompleteTableFrameForNumberOfRows:(NSInteger)numberOfRows
{
    [self.autoCompleteTableView.layer setCornerRadius:0];
    
    CGRect newAutoCompleteTableViewFrame = [self autoCompleteTableViewFrameForTextField:self forNumberOfRows:numberOfRows];
    [self.autoCompleteTableView setFrame:newAutoCompleteTableViewFrame];
    
    [self.autoCompleteTableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [self.autoCompleteTableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
}

- (void)resetDropDownAutoCompleteTableFrameForNumberOfRows:(NSInteger)numberOfRows
{
    [self.autoCompleteTableView.layer setCornerRadius:self.autoCompleteTableCornerRadius];
    
    CGRect newAutoCompleteTableViewFrame = [self autoCompleteTableViewFrameForTextField:self forNumberOfRows:numberOfRows];
    
    [self.autoCompleteTableView setFrame:newAutoCompleteTableViewFrame];
    [self.autoCompleteTableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
}

- (void)registerAutoCompleteCellNib:(UINib *)nib forCellReuseIdentifier:(NSString *)reuseIdentifier
{
    NSAssert(self.autoCompleteTableView, @"Must have an autoCompleteTableView to register cells to.");
    
    if(self.reuseIdentifier){
        [self unregisterAutoCompleteCellForReuseIdentifier:self.reuseIdentifier];
    }
    
    [self.autoCompleteTableView registerNib:nib forCellReuseIdentifier:reuseIdentifier];
    [self setReuseIdentifier:reuseIdentifier];
}


- (void)registerAutoCompleteCellClass:(Class)cellClass forCellReuseIdentifier:(NSString *)reuseIdentifier
{
    NSAssert(self.autoCompleteTableView, @"Must have an autoCompleteTableView to register cells to.");
    if(self.reuseIdentifier){
        [self unregisterAutoCompleteCellForReuseIdentifier:self.reuseIdentifier];
    }
    BOOL classSettingSupported = [self.autoCompleteTableView respondsToSelector:@selector(registerClass:forCellReuseIdentifier:)];
    NSAssert(classSettingSupported, @"Unable to set class for cell for autocomplete table, in iOS 5.0 you can set a custom NIB for a reuse identifier to get similar functionality.");
    [self.autoCompleteTableView registerClass:cellClass forCellReuseIdentifier:reuseIdentifier];
    [self setReuseIdentifier:reuseIdentifier];
}


- (void)unregisterAutoCompleteCellForReuseIdentifier:(NSString *)reuseIdentifier
{
    [self.autoCompleteTableView registerNib:nil forCellReuseIdentifier:reuseIdentifier];
}


- (void)styleAutoCompleteTableForBorderStyle:(UITextBorderStyle)borderStyle
{
    if([self.autoCompleteDelegate respondsToSelector:@selector(autoCompleteTextField:shouldStyleAutoCompleteTableView:forBorderStyle:)]){
        if(![self.autoCompleteDelegate autoCompleteTextField:self
                            shouldStyleAutoCompleteTableView:self.autoCompleteTableView
                                              forBorderStyle:borderStyle]){
            return;
        }
    }
    
    switch (borderStyle) {
        case UITextBorderStyleRoundedRect:
            [self setRoundedRectStyleForAutoCompleteTableView];
            break;
        case UITextBorderStyleBezel:
        case UITextBorderStyleLine:
            [self setLineStyleForAutoCompleteTableView];
            break;
        case UITextBorderStyleNone:
            [self setNoneStyleForAutoCompleteTableView];
            break;
        default:
            break;
    }
}

- (void)setRoundedRectStyleForAutoCompleteTableView
{
    [self setAutoCompleteTableCornerRadius:8.0];
    [self setAutoCompleteTableOriginOffset:CGSizeMake(0, -18)];
    [self setAutoCompleteScrollIndicatorInsets:UIEdgeInsetsMake(18, 0, 0, 0)];
    [self setAutoCompleteContentInsets:UIEdgeInsetsMake(18, 0, 0, 0)];
    
    if(self.backgroundColor == [UIColor clearColor]){
        [self setAutoCompleteTableBackgroundColor:[UIColor whiteColor]];
    } else {
        [self setAutoCompleteTableBackgroundColor:self.backgroundColor];
    }
}

- (void)setLineStyleForAutoCompleteTableView
{
    [self setAutoCompleteTableCornerRadius:0.0];
    [self setAutoCompleteTableOriginOffset:CGSizeZero];
    [self setAutoCompleteScrollIndicatorInsets:UIEdgeInsetsZero];
    [self setAutoCompleteContentInsets:UIEdgeInsetsZero];
    [self setAutoCompleteTableBorderWidth:1.0];
    [self setAutoCompleteTableBorderColor:[UIColor colorWithWhite:0.0 alpha:0.5]];
    
    if(self.backgroundColor == [UIColor clearColor]){
        [self setAutoCompleteTableBackgroundColor:[UIColor whiteColor]];
    } else {
        [self setAutoCompleteTableBackgroundColor:self.backgroundColor];
    }
}

- (void)setNoneStyleForAutoCompleteTableView
{
    [self setAutoCompleteTableCornerRadius:8.0];
    [self setAutoCompleteTableOriginOffset:CGSizeMake(0, 7)];
    [self setAutoCompleteScrollIndicatorInsets:UIEdgeInsetsZero];
    [self setAutoCompleteContentInsets:UIEdgeInsetsZero];
    [self setAutoCompleteTableBorderWidth:1.0];
    
    
    UIColor *lightBlueColor = [UIColor colorWithRed:181/255.0
                                              green:204/255.0
                                               blue:255/255.0
                                              alpha:1.0];
    [self setAutoCompleteTableBorderColor:lightBlueColor];
    
    
    UIColor *blueTextColor = [UIColor colorWithRed:23/255.0
                                             green:119/255.0
                                              blue:206/255.0
                                             alpha:1.0];
    [self setAutoCompleteTableCellTextColor:blueTextColor];
    
    if(self.backgroundColor == [UIColor clearColor]){
        [self setAutoCompleteTableBackgroundColor:[UIColor whiteColor]];
    } else {
        [self setAutoCompleteTableBackgroundColor:self.backgroundColor];
    }
}

-(void)setFontForAutoCompleteTextInsideTextField:(UIFont *)fontForAutoCompleteTextInsideTextField
{
    [self.autocompleteLabel setFont:fontForAutoCompleteTextInsideTextField];
}
- (void)saveCurrentShadowProperties
{
    [self setOriginalShadowColor:self.layer.shadowColor];
    [self setOriginalShadowOffset:self.layer.shadowOffset];
    [self setOriginalShadowOpacity:self.layer.shadowOpacity];
}

- (void)restoreOriginalShadowProperties
{
    [self.layer setShadowColor:self.originalShadowColor];
    [self.layer setShadowOffset:self.originalShadowOffset];
    [self.layer setShadowOpacity:self.originalShadowOpacity];
}

- (void)reloadData {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(fetchAutoCompleteSuggestions)
                                               object:nil];
    
    [self performSelector:@selector(fetchAutoCompleteSuggestions)
               withObject:nil
               afterDelay:self.autoCompleteFetchRequestDelay];
}

#pragma mark - Getters

- (BOOL)autoCompleteTableViewHidden
{
    return self.autoCompleteTableView.hidden;
}


- (void)fetchAutoCompleteSuggestions
{
     
    
    if(self.disableAutoCompleteTableUserInteractionWhileFetching){
        [self.autoCompleteTableView setUserInteractionEnabled:NO];
    }
    
    [self.autoCompleteFetchQueue cancelAllOperations];
    
    LSAutoCompleteFetchOperation *fetchOperation = [[LSAutoCompleteFetchOperation alloc]
                                                        initWithDelegate:self
                                                        completionsDataSource:self.autoCompleteDataSource
                                                        autoCompleteTextField:self];
    
    [self.autoCompleteFetchQueue addOperation:fetchOperation];
}



#pragma mark - Factory Methods

- (UITableView *)newAutoCompleteTableViewForTextField:(LSAutoCompleteTextField *)textField
{
    CGRect dropDownTableFrame = [self autoCompleteTableViewFrameForTextField:textField];
    
    UITableView *newTableView = [[UITableView alloc] initWithFrame:dropDownTableFrame
                                                             style:UITableViewStylePlain];
    [newTableView setDelegate:textField];
    [newTableView setDataSource:textField];
    [newTableView setScrollEnabled:YES];
    [newTableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    
    return newTableView;
}

- (CGRect)autoCompleteTableViewFrameForTextField:(LSAutoCompleteTextField *)textField
                                 forNumberOfRows:(NSInteger)numberOfRows
{
    CGRect newTableViewFrame             = [self autoCompleteTableViewFrameForTextField:textField];
    
    UIView *rootView                     = [textField.window.subviews objectAtIndex:0];
    CGRect textFieldFrameInContainerView = [rootView convertRect:textField.bounds
                                                        fromView:textField];
    
    CGFloat textfieldTopInset = textField.autoCompleteTableView.contentInset.top;
    CGFloat converted_originY = textFieldFrameInContainerView.origin.y + textfieldTopInset;
    CGFloat height = [self autoCompleteTableHeightForTextField:textField withNumberOfRows:numberOfRows];
    
    newTableViewFrame.size.height = height;
    newTableViewFrame.origin.y    = converted_originY;
    
    if(!textField.autoCompleteTableAppearsAsKeyboardAccessory){
        newTableViewFrame.size.height += textfieldTopInset;
    }
    
    return newTableViewFrame;
}

- (CGFloat)autoCompleteTableHeightForTextField:(LSAutoCompleteTextField *)textField
                              withNumberOfRows:(NSInteger)numberOfRows
{
    CGFloat maximumHeightMultiplier = (textField.maximumNumberOfAutoCompleteRows - textField.partOfAutoCompleteRowHeightToCut);
    CGFloat heightMultiplier;
    if(numberOfRows >= textField.maximumNumberOfAutoCompleteRows){
        heightMultiplier = maximumHeightMultiplier;
    } else {
        heightMultiplier = numberOfRows;
    }
    
    CGFloat height = textField.autoCompleteRowHeight * heightMultiplier;
    return height;
}

- (CGRect)autoCompleteTableViewFrameForTextField:(LSAutoCompleteTextField *)textField
{
    CGRect frame = CGRectZero;
    
    if (CGRectGetWidth(self.autoCompleteTableFrame) > 0){
        frame = self.autoCompleteTableFrame;
    } else {
        frame = textField.frame;
        frame.origin.y += textField.frame.size.height;
    }
    
    frame.origin.x += textField.autoCompleteTableOriginOffset.width;
    frame.origin.y += textField.autoCompleteTableOriginOffset.height;
    frame = CGRectInset(frame, 1, 0);
    
    return frame;
}

- (NSAttributedString *)boldedString:(NSString *)string withRange:(NSRange)boldRange
{
    UIFont *boldFont = [UIFont fontWithName:self.autoCompleteBoldFontName
                                       size:self.autoCompleteFontSize];
    UIFont *regularFont = [UIFont fontWithName:self.autoCompleteRegularFontName
                                          size:self.autoCompleteFontSize];
    
    NSDictionary *boldTextAttributes = @{NSFontAttributeName : boldFont};
    NSDictionary *regularTextAttributes = @{NSFontAttributeName : regularFont};
    NSDictionary *firstAttributes;
    NSDictionary *secondAttributes;
    
    if(self.reverseAutoCompleteSuggestionsBoldEffect){
        firstAttributes = regularTextAttributes;
        secondAttributes = boldTextAttributes;
    } else {
        firstAttributes = boldTextAttributes;
        secondAttributes = regularTextAttributes;
    }
    
    NSMutableAttributedString *attributedText =
    [[NSMutableAttributedString alloc] initWithString:string
                                           attributes:firstAttributes];
    [attributedText setAttributes:secondAttributes range:boldRange];
    
    return attributedText;
}



///  Edited by Rahul
#pragma mark- AutoComplete Label in TextField


- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self setupAutocompleteTextField];
}




- (void)setupAutocompleteTextField
{
    self.autocompleteLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    if (self.fontForAutoCompleteTextInsideTextField) {
     self.autocompleteLabel.font=self.fontForAutoCompleteTextInsideTextField;
    }
    else
    {
        self.autocompleteLabel.font=self.font;
    }
    
    self.autocompleteLabel.backgroundColor = [UIColor clearColor];
    if (self.colorForAutoCompleteTextInsideTextField) {
       self.autocompleteLabel.textColor = self.colorForAutoCompleteTextInsideTextField;
    }
    else
    {
        self.autocompleteLabel.textColor = [UIColor lightGrayColor];
    }
    
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
    NSLineBreakMode lineBreakMode = NSLineBreakByClipping;
#else
    UILineBreakMode lineBreakMode = UILineBreakModeClip;
#endif
    
    self.autocompleteLabel.lineBreakMode = lineBreakMode;
    self.autocompleteLabel.hidden = YES;
    [self addSubview:self.autocompleteLabel];
    [self bringSubviewToFront:self.autocompleteLabel];
    
    self.autocompleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.autocompleteButton addTarget:self action:@selector(autocompleteText:) forControlEvents:UIControlEventTouchUpInside];
    [self.autocompleteButton setImage:[UIImage imageNamed:@"autocompleteButton"] forState:UIControlStateNormal];
    
    [self addSubview:self.autocompleteButton];
    [self bringSubviewToFront:self.autocompleteButton];
    
    self.autocompleteString = @"";
    
    self.ignoreCase = YES;
    
 //   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ht_textDidChange:) name:UITextFieldTextDidChangeNotification object:self];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.autocompleteButton.frame = [self frameForAutocompleteButton];
}



#pragma mark - Autocomplete Logic

- (CGRect)autocompleteRectForBounds:(CGRect)bounds
{
    CGRect returnRect = CGRectZero;
    CGRect textRect = [self textRectForBounds:self.bounds];
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
    NSLineBreakMode lineBreakMode = NSLineBreakByCharWrapping;
#else
    UILineBreakMode lineBreakMode = UILineBreakModeCharacterWrap;
#endif
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    paragraphStyle.lineBreakMode = lineBreakMode;
    
    NSDictionary *attributes = @{NSFontAttributeName: self.font,
                                 NSParagraphStyleAttributeName: paragraphStyle};
    CGRect prefixTextRect = [self.text boundingRectWithSize:textRect.size
                                                    options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading
                                                 attributes:attributes context:nil];
    CGSize prefixTextSize = prefixTextRect.size;
    
    CGRect autocompleteTextRect = [self.autocompleteString boundingRectWithSize:CGSizeMake(textRect.size.width-prefixTextSize.width, textRect.size.height)
                                                                        options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading
                                                                     attributes:attributes context:nil];
    CGSize autocompleteTextSize = autocompleteTextRect.size;
#else
    CGSize prefixTextSize = [self.text sizeWithFont:self.font
                                  constrainedToSize:textRect.size
                                      lineBreakMode:lineBreakMode];
    
    CGSize autocompleteTextSize = [self.autocompleteString sizeWithFont:self.font
                                                      constrainedToSize:CGSizeMake(textRect.size.width-prefixTextSize.width, textRect.size.height)
                                                          lineBreakMode:lineBreakMode];
#endif
    
    returnRect = CGRectMake(textRect.origin.x + prefixTextSize.width + self.autocompleteTextOffset.x,
                            textRect.origin.y + self.autocompleteTextOffset.y,
                            autocompleteTextSize.width,
                            textRect.size.height);
    
    return returnRect;
}

- (void)ht_textDidChange:(NSNotification*)notification
{
    [self refreshAutocompleteText];
}

- (void)updateAutocompleteLabel
{
    [self.autocompleteLabel setText:self.autocompleteString];
    [self.autocompleteLabel sizeToFit];
    [self.autocompleteLabel setFrame: [self autocompleteRectForBounds:self.bounds]];
    [self sendActionsForControlEvents:UIControlEventEditingChanged];
    /*
	if ([self.autoCompleteTextFieldDelegate respondsToSelector:@selector(autocompleteTextField:didChangeAutocompleteText:)]) {
		[self.autoCompleteTextFieldDelegate autocompleteTextField:self didChangeAutocompleteText:self.autocompleteString];
	}
     */
}

- (void)refreshAutocompleteText
{
    if (!self.autocompleteDisabled)
    {
        
            self.autocompleteString = [self completionForPrefix:self.text ignoreCase:self.ignoreCase];
            
            if (self.autocompleteString.length > 0)
            {
                if (self.text.length == 0 || self.text.length == 1)
                {
                    [self updateAutocompleteButtonAnimated:YES];
                }
            }
            
            [self updateAutocompleteLabel];
        
    }
    
}
- (NSString *)completionForPrefix:(NSString *)prefix ignoreCase:(BOOL)ignoreCase
{
    
    
    NSString *stringToLookFor;
    NSArray *componentsString = [prefix componentsSeparatedByString:@","];
    NSString *prefixLastComponent = [componentsString.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (ignoreCase)
    {
        stringToLookFor = [prefixLastComponent lowercaseString];
    }
    else
    {
        stringToLookFor = prefixLastComponent;
    }
    
    for (NSString *stringFromReference in self.autoCompleteSuggestions)
    {
        NSString *stringToCompare;
        if (ignoreCase)
        {
            stringToCompare = [stringFromReference lowercaseString];
        }
        else
        {
            stringToCompare = stringFromReference;
        }
        
        if ([stringToCompare hasPrefix:stringToLookFor])
        {
            return [stringFromReference stringByReplacingCharactersInRange:[stringToCompare rangeOfString:stringToLookFor] withString:@""];
        }
        
    }
    return @"";
    
}


- (BOOL)commitAutocompleteText
{
    NSString *currentText = self.text;
    if (self.autocompleteString.length > 0
        && self.autocompleteDisabled == NO)
    {
        self.text = [NSString stringWithFormat:@"%@%@", self.text, self.autocompleteString];
        
        self.autocompleteString = @"";
        [self updateAutocompleteLabel];
		/*
		if ([self.autoCompleteTextFieldDelegate respondsToSelector:@selector(autoCompleteTextFieldDidAutoComplete:)]) {
			[self.autoCompleteTextFieldDelegate autoCompleteTextFieldDidAutoComplete:self];
		}
         */
    }
    return ![currentText isEqualToString:self.text];
}

- (void)forceRefreshAutocompleteText
{
    [self refreshAutocompleteText];
}

#pragma mark - Accessors

- (void)setAutocompleteString:(NSString *)autocompleteString
{
    _autocompleteString = autocompleteString;
    
    [self updateAutocompleteButtonAnimated:YES];
}

- (void)setShowAutocompleteButton:(BOOL)showAutocompleteButton
{
    _showAutocompleteButton = showAutocompleteButton;
    
    [self updateAutocompleteButtonAnimated:YES];
}

#pragma mark - Private Methods

- (CGRect)frameForAutocompleteButton
{
    CGRect autocompletionButtonRect;
    if (self.clearButtonMode == UITextFieldViewModeNever || self.text.length == 0)
    {
        autocompletionButtonRect = CGRectMake(self.bounds.size.width - kHTAutoCompleteButtonWidth, (self.bounds.size.height/2) - (self.bounds.size.height-8)/2, kHTAutoCompleteButtonWidth, self.bounds.size.height-8);
    }
    else
    {
        autocompletionButtonRect = CGRectMake(self.bounds.size.width - 25 - kHTAutoCompleteButtonWidth, (self.bounds.size.height/2) - (self.bounds.size.height-8)/2, kHTAutoCompleteButtonWidth, self.bounds.size.height-8);
    }
    return autocompletionButtonRect;
}

// Method fired by autocompleteButton for multiRecognition
- (void)autocompleteText:(id)sender
{
    if (!self.autocompleteDisabled)
    {
        self.autocompleteLabel.hidden = NO;
        
        [self commitAutocompleteText];
        
        // This is necessary because committing the autocomplete text changes the text field's text, but for some reason UITextField doesn't post the UITextFieldTextDidChangeNotification notification on its own
        [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification
                                                            object:self];
    }
}

- (void)updateAutocompleteButtonAnimated:(BOOL)animated
{
    void (^action)(void) = ^{
        if (self.autocompleteString.length && self.showAutocompleteButton)
        {
            self.autocompleteButton.alpha = 1;
            self.autocompleteButton.frame = [self frameForAutocompleteButton];
        }
        else
        {
            self.autocompleteButton.alpha = 0;
        }
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.15f animations:^{
            action();
        }];
    }
    else
    {
        action();
    }
}






- (void)drawPlaceholderInRect:(CGRect)rect {
   
    UIFont *font=self.fontForAutoCompletePlaceholder?self.fontForAutoCompletePlaceholder:self.font;
    UIColor *color=self.autoCompletePlaceholderTextColor?self.autoCompletePlaceholderTextColor:self.textColor;
    
    
    
    [self.placeholder drawInRect:rect
                  withAttributes:@{
                                   NSFontAttributeName:
                                       font,NSForegroundColorAttributeName:color
                                                                    }];
}



/// Edited by Rahul







@end







#pragma mark -
#pragma mark - LSAutoCompleteFetchOperation
@implementation LSAutoCompleteFetchOperation{
    dispatch_semaphore_t sentinelSemaphore;
}

- (void) cancel
{
    dispatch_semaphore_signal(sentinelSemaphore);
    [super cancel];
}

- (void)main
{
    @autoreleasepool {
        
        if (self.isCancelled){
            return;
        }
        
        
        if([self.dataSource respondsToSelector:@selector(autoCompleteTextField:possibleCompletionsForString:completionHandler:)]){
            __weak LSAutoCompleteFetchOperation *operation = self;
            sentinelSemaphore = dispatch_semaphore_create(0);
            [self.dataSource autoCompleteTextField:self.textField
                      possibleCompletionsForString:self.incompleteString
                                 completionHandler:^(NSArray *suggestions){
                                     
                                     [operation performSelector:@selector(didReceiveSuggestions:) withObject:suggestions];
                                     dispatch_semaphore_signal(sentinelSemaphore);
                                 }];
            
            dispatch_semaphore_wait(sentinelSemaphore, DISPATCH_TIME_FOREVER);
            if(self.isCancelled){
                return;
            }
        } else if ([self.dataSource respondsToSelector:@selector(autoCompleteTextField:possibleCompletionsForString:)]){
            
            NSArray *results = [self.dataSource autoCompleteTextField:self.textField
                                possibleCompletionsForString:self.incompleteString];
            
            if(!self.isCancelled){
                [self didReceiveSuggestions:results];
            }
            
        } else {
            NSAssert(0, @"An autocomplete datasource must implement either autoCompleteTextField:possibleCompletionsForString: or autoCompleteTextField:possibleCompletionsForString:completionHandler:");
        }
        
    }
}

- (void)didReceiveSuggestions:(NSArray *)suggestions
{
    if(suggestions == nil){
        suggestions = [NSArray array];
    }
    
    if(!self.isCancelled){
        
        if(suggestions.count){
            NSObject *firstObject = suggestions[0];
            NSAssert([firstObject isKindOfClass:[NSString class]],
                     @"LSAutoCompleteTextField expects an array with objects that are either strings.");
        }
        
        NSDictionary *resultsInfo = @{kFetchedTermsKey: suggestions,
                                      kFetchedStringKey : self.incompleteString};
        [(NSObject *)self.delegate
         performSelectorOnMainThread:@selector(autoCompleteTermsDidFetch:)
         withObject:resultsInfo
         waitUntilDone:NO];
    };
}

- (id)initWithDelegate:(id<LSAutoCompleteFetchOperationDelegate>)aDelegate
 completionsDataSource:(id<LSAutoCompleteTextFieldDataSource>)aDataSource
 autoCompleteTextField:(LSAutoCompleteTextField *)aTextField
{
    self = [super init];
    if (self) {
        [self setDelegate:aDelegate];
        [self setTextField:aTextField];
        [self setDataSource:aDataSource];
        [self setIncompleteString:aTextField.text];
        
        if(!self.incompleteString){
            self.incompleteString = @"";
        }
    }
    return self;
}

- (void)dealloc
{
    [self setDelegate:nil];
    [self setTextField:nil];
    [self setDataSource:nil];
    [self setIncompleteString:nil];
}
@end





#pragma mark -
#pragma mark - LSAutoCompleteSortOperation

@implementation LSAutoCompleteSortOperation

- (void)main
{
    @autoreleasepool {
        
        if (self.isCancelled){
            return;
        }
        
        NSArray *results = [self sortedCompletionsForString:self.incompleteString
                                        withPossibleStrings:self.possibleCompletions];
        
        if (self.isCancelled){
            return;
        }
        
        if(!self.isCancelled){
            [(NSObject *)self.delegate
             performSelectorOnMainThread:@selector(autoCompleteTermsDidSort:)
             withObject:results
             waitUntilDone:NO];
        }
    }
}

- (id)initWithDelegate:(id<LSAutoCompleteSortOperationDelegate>)aDelegate
      incompleteString:(NSString *)string
   possibleCompletions:(NSArray *)possibleStrings
{
    self = [super init];
    if (self) {
        [self setDelegate:aDelegate];
        [self setIncompleteString:string];
        [self setPossibleCompletions:possibleStrings];
    }
    return self;
}

- (NSArray *)sortedCompletionsForString:(NSString *)inputString withPossibleStrings:(NSArray *)possibleTerms
{
    if([inputString isEqualToString:@""]){
        return possibleTerms;
    }
    
    if(self.isCancelled){
        return [NSArray array];
    }
    
    NSMutableArray *editDistances = [NSMutableArray arrayWithCapacity:possibleTerms.count];
    
    
    for(NSObject *originalObject in possibleTerms) {
        
        NSString *currentString;
        if([originalObject isKindOfClass:[NSString class]]){
            currentString = (NSString *)originalObject;
        } else {
            NSAssert(0, @"Autocompletion terms must either be strings or objects conforming to the LSAutoCompleteObject protocol.");
        }
        
        if(self.isCancelled){
            return [NSArray array];
        }
        
        NSUInteger maximumRange = (inputString.length < currentString.length) ? inputString.length : currentString.length;
        float editDistanceOfCurrentString = [inputString asciiLevenshteinDistanceWithString:[currentString substringWithRange:NSMakeRange(0, maximumRange)]];
        
        NSDictionary * stringsWithEditDistances = @{kSortInputStringKey : currentString ,
                                                         kSortObjectKey : originalObject,
                                                  kSortEditDistancesKey : [NSNumber numberWithFloat:editDistanceOfCurrentString]};
        [editDistances addObject:stringsWithEditDistances];
    }
    
    if(self.isCancelled){
        return [NSArray array];
    }
    
    [editDistances sortUsingComparator:^(NSDictionary *string1Dictionary,
                                         NSDictionary *string2Dictionary){
        
        return [string1Dictionary[kSortEditDistancesKey]
                compare:string2Dictionary[kSortEditDistancesKey]];
        
    }];
    
    
    
    NSMutableArray *prioritySuggestions = [NSMutableArray array];
    NSMutableArray *otherSuggestions = [NSMutableArray array];
    for(NSDictionary *stringsWithEditDistances in editDistances){
        
        if(self.isCancelled){
            return [NSArray array];
        }
        
        NSObject *autoCompleteObject = stringsWithEditDistances[kSortObjectKey];
        NSString *suggestedString = stringsWithEditDistances[kSortInputStringKey];
    
        NSArray *suggestedStringComponents = [suggestedString componentsSeparatedByString:@" "];
        BOOL suggestedStringDeservesPriority = NO;
        for(NSString *component in suggestedStringComponents){
            NSRange occurrenceOfInputString = [[component lowercaseString]
                                            rangeOfString:[inputString lowercaseString]];
            
            if (occurrenceOfInputString.length != 0 && occurrenceOfInputString.location == 0) {
                suggestedStringDeservesPriority = YES;
                [prioritySuggestions addObject:autoCompleteObject];
                break;
            }
    
            if([inputString length] <= 1){
                //if the input string is very short, don't check anymore components of the input string.
                break;
            }
        }
        
        if(!suggestedStringDeservesPriority){
            [otherSuggestions addObject:autoCompleteObject];
        }

    }
    
    NSMutableArray *results = [NSMutableArray array];
    [results addObjectsFromArray:prioritySuggestions];
    [results addObjectsFromArray:otherSuggestions];
    
    
    return [NSArray arrayWithArray:results];
}



- (void)dealloc
{
    [self setDelegate:nil];
    [self setIncompleteString:nil];
    [self setPossibleCompletions:nil];
}
@end

