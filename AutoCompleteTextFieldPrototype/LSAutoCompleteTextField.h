



#import <UIKit/UIKit.h>




@class LSAutoCompleteTextField;
@protocol LSAutoCompleteTextFieldDelegate <NSObject>

@optional
- (BOOL)autoCompleteTextField:(LSAutoCompleteTextField *)textField
shouldStyleAutoCompleteTableView:(UITableView *)autoCompleteTableView
               forBorderStyle:(UITextBorderStyle)borderStyle;


/*IndexPath corresponds to the order of strings within the autocomplete table,
 not the original data source.*/
- (BOOL)autoCompleteTextField:(LSAutoCompleteTextField *)textField
          shouldConfigureCell:(UITableViewCell *)cell
       withAutoCompleteString:(NSString *)autocompleteString
         withAttributedString:(NSAttributedString *)boldedString
            forRowAtIndexPath:(NSIndexPath *)indexPath;


/*IndexPath corresponds to the order of strings within the autocomplete table,
 not the original data source.
 autoCompleteObject may be nil if the selectedString had no object associated with it.
 */
- (void)autoCompleteTextField:(LSAutoCompleteTextField *)textField
  didSelectAutoCompleteString:(NSString *)selectedString
            forRowAtIndexPath:(NSIndexPath *)indexPath;




- (void)autoCompleteTextField:(LSAutoCompleteTextField *)textField
willShowAutoCompleteTableView:(UITableView *)autoCompleteTableView;

- (void)autoCompleteTextField:(LSAutoCompleteTextField *)textField
 didChangeNumberOfSuggestions:(NSInteger)numberOfSuggestions;

@end


@class LSAutoCompleteTextField;
@protocol LSAutoCompleteTextFieldDataSource <NSObject>


@optional
//One of these two methods must be implemented to fetch autocomplete terms.


/*
 When you have the suggestions ready you must call the completionHandler block with
 an NSArray of strings or objects implementing the LSAutoCompletionObject protocol that
 could be used as possible completions for the given string in textField.
 */
- (void)autoCompleteTextField:(LSAutoCompleteTextField *)textField
 possibleCompletionsForString:(NSString *)string
            completionHandler:(void(^)(NSArray *suggestions))handler;



/*
 Like the above, this method should return an NSArray of strings or objects implementing the LSAutoCompletionObject protocol
 that could be used as possible completions for the given string in textField.
 This method will be called asynchronously, so an immediate return is not necessary.
 */
- (NSArray *)autoCompleteTextField:(LSAutoCompleteTextField *)textField
      possibleCompletionsForString:(NSString *)string;



@end



@protocol LSAutoCompleteSortOperationDelegate <NSObject>
- (void)autoCompleteTermsDidSort:(NSArray *)completions;
@end

@protocol LSAutoCompleteFetchOperationDelegate <NSObject>
- (void)autoCompleteTermsDidFetch:(NSDictionary *)fetchInfo;
@end


@interface LSAutoCompleteTextField : UITextField <UITableViewDataSource, UITableViewDelegate, LSAutoCompleteSortOperationDelegate, LSAutoCompleteFetchOperationDelegate>

+ (NSString *) accessibilityLabelForIndexPath:(NSIndexPath *)indexPath;

@property (strong, readonly) UITableView *autoCompleteTableView;

// all delegates and datasources should be weak referenced
@property (weak) IBOutlet id <LSAutoCompleteTextFieldDataSource> autoCompleteDataSource;
@property (weak) IBOutlet id <LSAutoCompleteTextFieldDelegate> autoCompleteDelegate;

@property (assign) NSTimeInterval autoCompleteFetchRequestDelay; //default is 0.1, if you fetch from a web service you may want this higher to prevent multiple calls happening very quickly.
@property (assign) BOOL sortAutoCompleteSuggestionsByClosestMatch;
@property (assign) BOOL applyBoldEffectToAutoCompleteSuggestions;
@property (assign) BOOL reverseAutoCompleteSuggestionsBoldEffect;
@property (assign) BOOL showTextFieldDropShadowWhenAutoCompleteTableIsOpen;
@property (assign) BOOL showAutoCompleteTableWhenEditingBegins; //only applies for drop down style autocomplete tables.
@property (assign) BOOL disableAutoCompleteTableUserInteractionWhileFetching;
@property (assign) BOOL autoCompleteTableAppearsAsKeyboardAccessory; //if set to TRUE, the autocomplete table will appear as a keyboard input accessory view rather than a drop down.
@property (assign) BOOL shouldResignFirstResponderFromKeyboardAfterSelectionOfAutoCompleteRows; // default is TRUE


@property (assign) BOOL autoCompleteTableViewHidden;

@property (assign) CGFloat autoCompleteFontSize;
@property (strong) NSString *autoCompleteBoldFontName;
@property (strong) NSString *autoCompleteRegularFontName;

@property (assign) NSInteger maximumNumberOfAutoCompleteRows;
@property (assign) CGFloat partOfAutoCompleteRowHeightToCut; // this number multiplied by autoCompleteRowHeight will be subtracted from total tableView height.
@property (assign) CGFloat autoCompleteRowHeight;
@property (nonatomic, assign) CGRect autoCompleteTableFrame;
@property (assign) CGSize autoCompleteTableOriginOffset;
@property (assign) CGFloat autoCompleteTableCornerRadius; //only applies for drop down style autocomplete tables.
@property (nonatomic, assign) UIEdgeInsets autoCompleteContentInsets;
@property (nonatomic, assign) UIEdgeInsets autoCompleteScrollIndicatorInsets;
@property (nonatomic, strong) UIColor *autoCompleteTableBorderColor;
@property (nonatomic, assign) CGFloat autoCompleteTableBorderWidth;
@property (nonatomic, strong) UIColor *autoCompleteTableBackgroundColor;
@property (strong) UIColor *autoCompleteTableCellBackgroundColor;
@property (strong) UIColor *autoCompleteTableCellTextColor;

@property(nonatomic,strong)UIFont *fontForAutoCompleteTextInsideTextField;
@property(strong)UIColor *colorForAutoCompleteTextInsideTextField;

-(void)setFontForPlaceholer:(UIFont*)font andColor:(UIColor*)color;

- (void)registerAutoCompleteCellNib:(UINib *)nib forCellReuseIdentifier:(NSString *)reuseIdentifier;

- (void)registerAutoCompleteCellClass:(Class)cellClass forCellReuseIdentifier:(NSString *)reuseIdentifier;

- (void)reloadData; //it will ask DataSource for data again
@end


