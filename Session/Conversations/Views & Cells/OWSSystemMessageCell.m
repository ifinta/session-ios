//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSSystemMessageCell.h"
#import "ConversationViewItem.h"
#import "OWSMessageHeaderView.h"
#import "Session-Swift.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIView+OWS.h"
#import <SessionMessagingKit/OWSDisappearingConfigurationUpdateInfoMessage.h>
#import <SessionMessagingKit/Environment.h>
#import <SessionMessagingKit/TSErrorMessage.h>
#import <SessionMessagingKit/TSInfoMessage.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SystemMessageActionBlock)(void);

@interface SystemMessageAction : NSObject

@property (nonatomic) NSString *title;
@property (nonatomic) SystemMessageActionBlock block;

@end

#pragma mark -

@implementation SystemMessageAction

+ (SystemMessageAction *)actionWithTitle:(NSString *)title block:(SystemMessageActionBlock)block
{
    SystemMessageAction *action = [SystemMessageAction new];
    action.title = title;
    action.block = block;
    return action;
}

@end

#pragma mark -

@interface OWSSystemMessageCell ()

@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UIButton *button;
@property (nonatomic) UIStackView *vStackView;
@property (nonatomic) UIView *cellBackgroundView;
@property (nonatomic) OWSMessageHeaderView *headerView;
@property (nonatomic) NSLayoutConstraint *headerViewHeightConstraint;
@property (nonatomic) NSArray<NSLayoutConstraint *> *layoutConstraints;
@property (nonatomic, nullable) SystemMessageAction *action;

@end

#pragma mark -

@implementation OWSSystemMessageCell

// `[UIView init]` invokes `[self initWithFrame:...]`.
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }

    return self;
}

- (void)commonInit
{
    OWSAssertDebug(!self.iconView);

    self.layoutMargins = UIEdgeInsetsZero;
    self.contentView.layoutMargins = UIEdgeInsetsZero;
    self.layoutConstraints = @[];

    self.headerView = [OWSMessageHeaderView new];
    self.headerViewHeightConstraint = [self.headerView autoSetDimension:ALDimensionHeight toSize:0];

    self.iconView = [UIImageView new];
    [self.iconView autoSetDimension:ALDimensionWidth toSize:self.iconSize];
    [self.iconView autoSetDimension:ALDimensionHeight toSize:self.iconSize];
    [self.iconView setContentHuggingHigh];

    self.titleLabel = [UILabel new];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;

    UIStackView *contentStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.iconView,
        self.titleLabel,
    ]];
    contentStackView.axis = UILayoutConstraintAxisVertical;
    contentStackView.spacing = self.iconVSpacing;
    contentStackView.alignment = UIStackViewAlignmentCenter;

    self.button = [UIButton new];
    [self.button setTitleColor:[UIColor ows_darkSkyBlueColor] forState:UIControlStateNormal];
    self.button.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.button.layer.cornerRadius = LKValues.modalButtonCornerRadius;
    self.button.backgroundColor = LKColors.buttonBackground;
    self.button.titleLabel.font = [UIFont systemFontOfSize:LKValues.smallFontSize];
    [self.button addTarget:self action:@selector(buttonWasPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.button autoSetDimension:ALDimensionHeight toSize:self.buttonHeight];

    self.vStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        contentStackView,
        self.button,
    ]];
    self.vStackView.axis = UILayoutConstraintAxisVertical;
    self.vStackView.spacing = self.buttonVSpacing;
    self.vStackView.alignment = UIStackViewAlignmentCenter;
    self.vStackView.layoutMarginsRelativeArrangement = YES;

    self.cellBackgroundView = [UIView new];
    self.cellBackgroundView.layer.cornerRadius = 5.f;
    [self.contentView addSubview:self.cellBackgroundView];

    UIStackView *cellStackView = [[UIStackView alloc] initWithArrangedSubviews:@[ self.headerView, self.vStackView ]];
    cellStackView.axis = UILayoutConstraintAxisVertical;
    [self.contentView addSubview:cellStackView];
    [cellStackView autoPinEdgesToSuperviewEdges];

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGesture:)];
    [self addGestureRecognizer:longPress];
}

- (CGFloat)buttonVSpacing
{
    return 12.f;
}

- (CGFloat)iconVSpacing
{
    return LKValues.smallSpacing;
}

- (CGFloat)buttonHeight
{
    return LKValues.mediumButtonHeight;
}

- (CGFloat)buttonHPadding
{
    return 20.f;
}

- (void)configureFonts
{
    // Update cell to reflect changes in dynamic text.
    self.titleLabel.font = [UIFont systemFontOfSize:LKValues.smallFontSize];
}

+ (NSString *)cellReuseIdentifier
{
    return NSStringFromClass([self class]);
}

- (void)loadForDisplay
{
    OWSAssertDebug(self.conversationStyle);
    OWSAssertDebug(self.viewItem);

    self.cellBackgroundView.backgroundColor = UIColor.clearColor;

    [self.button setBackgroundColor:LKColors.buttonBackground];

    TSInteraction *interaction = self.viewItem.interaction;

    self.action = [self actionForInteraction:interaction];

    UIImage *_Nullable icon = [self iconForInteraction:interaction];
    if (icon) {
        self.iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.iconView.hidden = NO;
        self.iconView.tintColor = LKColors.text;
    } else {
        self.iconView.hidden = YES;
    }

    self.titleLabel.textColor = [self textColor];
    [self applyTitleForInteraction:interaction label:self.titleLabel];
    CGSize titleSize = [self titleSize];

    if (self.action) {
        [self.button setTitle:self.action.title forState:UIControlStateNormal];
        UIFont *buttonFont = [UIFont systemFontOfSize:LKValues.smallFontSize];
        self.button.titleLabel.font = buttonFont;
        [self.button setTitleColor:LKColors.text forState:UIControlStateNormal];
        self.button.hidden = NO;
    } else {
        self.button.hidden = YES;
    }
    CGSize buttonSize = [self.button sizeThatFits:CGSizeZero];

    [NSLayoutConstraint deactivateConstraints:self.layoutConstraints];

    if (self.viewItem.hasCellHeader) {
        self.headerView.hidden = NO;

        CGFloat headerHeight =
            [self.headerView measureWithConversationViewItem:self.viewItem conversationStyle:self.conversationStyle]
                .height;

        [self.headerView loadForDisplayWithViewItem:self.viewItem conversationStyle:self.conversationStyle];
        self.headerViewHeightConstraint.constant = headerHeight;
    } else {
        self.headerView.hidden = YES;
    }

    self.vStackView.layoutMargins = UIEdgeInsetsMake(self.topVMargin,
        self.conversationStyle.fullWidthGutterLeading,
        self.bottomVMargin,
        self.conversationStyle.fullWidthGutterLeading);

    self.layoutConstraints = @[
        [self.titleLabel autoSetDimension:ALDimensionWidth toSize:titleSize.width],
        [self.button autoSetDimension:ALDimensionWidth toSize:buttonSize.width + self.buttonHPadding * 2.f],

        [self.cellBackgroundView autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.vStackView],
        [self.cellBackgroundView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.vStackView],
        // Text in vStackView might flow right up to the edges, so only use half the gutter.
        [self.cellBackgroundView autoPinEdgeToSuperviewEdge:ALEdgeLeading
                                                  withInset:self.conversationStyle.fullWidthGutterLeading * 0.5f],
        [self.cellBackgroundView autoPinEdgeToSuperviewEdge:ALEdgeTrailing
                                                  withInset:self.conversationStyle.fullWidthGutterTrailing * 0.5f],
    ];
}

- (UIColor *)textColor
{
    return LKColors.text;
}

- (UIColor *)iconColorForInteraction:(TSInteraction *)interaction
{
    return LKColors.text;
}

- (nullable UIImage *)iconForInteraction:(TSInteraction *)interaction
{
    UIImage *result = nil;

    if ([interaction isKindOfClass:[TSErrorMessage class]]) {
        switch (((TSErrorMessage *)interaction).errorType) {
            case TSErrorMessageNonBlockingIdentityChange:
            case TSErrorMessageWrongTrustedIdentityKey:
                result = [UIImage imageNamed:@"system_message_security"];
                break;
            case TSErrorMessageInvalidKeyException:
            case TSErrorMessageMissingKeyId:
            case TSErrorMessageNoSession:
            case TSErrorMessageInvalidMessage:
            case TSErrorMessageDuplicateMessage:
            case TSErrorMessageInvalidVersion:
            case TSErrorMessageUnknownContactBlockOffer:
            case TSErrorMessageGroupCreationFailed:
                return nil;
        }
    } else if ([interaction isKindOfClass:[TSInfoMessage class]]) {
        switch (((TSInfoMessage *)interaction).messageType) {
            case TSInfoMessageUserNotRegistered:
            case TSInfoMessageTypeSessionDidEnd:
            case TSInfoMessageTypeUnsupportedMessage:
            case TSInfoMessageAddToContactsOffer:
            case TSInfoMessageAddUserToProfileWhitelistOffer:
            case TSInfoMessageAddGroupToProfileWhitelistOffer:
            case TSInfoMessageTypeGroupUpdate:
            case TSInfoMessageTypeGroupQuit:
            case TSInfoMessageTypeLokiSessionResetInProgress:
            case TSInfoMessageTypeLokiSessionResetDone:
                return nil;
            case TSInfoMessageTypeDisappearingMessagesUpdate: {
                BOOL areDisappearingMessagesEnabled = YES;
                if ([interaction isKindOfClass:[OWSDisappearingConfigurationUpdateInfoMessage class]]) {
                    areDisappearingMessagesEnabled
                        = ((OWSDisappearingConfigurationUpdateInfoMessage *)interaction).configurationIsEnabled;
                } else {
                    OWSFailDebug(@"unexpected interaction type: %@", interaction.class);
                }
                result = (areDisappearingMessagesEnabled
                        ? [UIImage imageNamed:@"system_message_disappearing_messages"]
                        : [UIImage imageNamed:@"system_message_disappearing_messages_disabled"]);
                break;
            }
        }
    } else {
        OWSFailDebug(@"Unknown interaction type: %@", [interaction class]);
        return nil;
    }
    OWSAssertDebug(result);
    return result;
}

- (void)applyTitleForInteraction:(TSInteraction *)interaction
                           label:(UILabel *)label
{
    OWSAssertDebug(interaction);
    OWSAssertDebug(label);
    OWSAssertDebug(self.viewItem.systemMessageText.length > 0);

    [self configureFonts];

    label.text = self.viewItem.systemMessageText;
}

- (CGFloat)topVMargin
{
    return LKValues.smallSpacing;
}

- (CGFloat)bottomVMargin
{
    return LKValues.smallSpacing;
}

- (CGFloat)hSpacing
{
    return LKValues.mediumSpacing;
}

- (CGFloat)iconSize
{
    return 20.f;
}

- (CGSize)titleSize
{
    OWSAssertDebug(self.conversationStyle);
    OWSAssertDebug(self.viewItem);

    CGFloat maxTitleWidth = (CGFloat)floor(self.conversationStyle.fullWidthContentWidth);
    return [self.titleLabel sizeThatFits:CGSizeMake(maxTitleWidth, CGFLOAT_MAX)];
}

- (CGSize)cellSize
{
    OWSAssertDebug(self.conversationStyle);
    OWSAssertDebug(self.viewItem);

    TSInteraction *interaction = self.viewItem.interaction;

    CGSize result = CGSizeMake(self.conversationStyle.viewWidth, 0);

    if (self.viewItem.hasCellHeader) {
        result.height +=
            [self.headerView measureWithConversationViewItem:self.viewItem conversationStyle:self.conversationStyle]
                .height;
    }

    UIImage *_Nullable icon = [self iconForInteraction:interaction];
    if (icon) {
        result.height += self.iconSize + self.iconVSpacing;
    }

    [self applyTitleForInteraction:interaction label:self.titleLabel];
    CGSize titleSize = [self titleSize];
    result.height += titleSize.height;

    SystemMessageAction *_Nullable action = [self actionForInteraction:interaction];
    if (action) {
        result.height += self.buttonHeight + self.buttonVSpacing;
    }

    result.height += self.topVMargin + self.bottomVMargin;

    return result;
}

#pragma mark - Actions

- (nullable SystemMessageAction *)actionForInteraction:(TSInteraction *)interaction
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(interaction);

    if ([interaction isKindOfClass:[TSErrorMessage class]]) {
        return [self actionForErrorMessage:(TSErrorMessage *)interaction];
    } else if ([interaction isKindOfClass:[TSInfoMessage class]]) {
        return [self actionForInfoMessage:(TSInfoMessage *)interaction];
    } else {
        OWSFailDebug(@"Tap for system messages of unknown type: %@", [interaction class]);
        return nil;
    }
}

- (nullable SystemMessageAction *)actionForErrorMessage:(TSErrorMessage *)message
{
    OWSAssertDebug(message);

    __weak OWSSystemMessageCell *weakSelf = self;
    switch (message.errorType) {
        case TSErrorMessageInvalidKeyException:
            return nil;
        case TSErrorMessageMissingKeyId:
        case TSErrorMessageNoSession:
        case TSErrorMessageInvalidMessage:
            return nil;
        case TSErrorMessageDuplicateMessage:
        case TSErrorMessageInvalidVersion:
            return nil;
        case TSErrorMessageUnknownContactBlockOffer:
            OWSFailDebug(@"TSErrorMessageUnknownContactBlockOffer");
            return nil;
        case TSErrorMessageGroupCreationFailed:
            return [SystemMessageAction actionWithTitle:CommonStrings.retryButton
                                                  block:^{
                                                      [weakSelf.delegate resendGroupUpdateForErrorMessage:message];
                                                  }];
    }

    OWSLogWarn(@"Unhandled tap for error message:%@", message);
    return nil;
}

- (nullable SystemMessageAction *)actionForInfoMessage:(TSInfoMessage *)message
{
    OWSAssertDebug(message);

    __weak OWSSystemMessageCell *weakSelf = self;
    switch (message.messageType) {
        case TSInfoMessageUserNotRegistered:
        case TSInfoMessageTypeSessionDidEnd:
        case TSInfoMessageTypeLokiSessionResetInProgress:
        case TSInfoMessageTypeLokiSessionResetDone:
            return nil;
        case TSInfoMessageTypeUnsupportedMessage:
            // Unused.
            return nil;
        case TSInfoMessageAddToContactsOffer:
            // Unused.
            OWSFailDebug(@"TSInfoMessageAddToContactsOffer");
            return nil;
        case TSInfoMessageAddUserToProfileWhitelistOffer:
            // Unused.
            OWSFailDebug(@"TSInfoMessageAddUserToProfileWhitelistOffer");
            return nil;
        case TSInfoMessageAddGroupToProfileWhitelistOffer:
            // Unused.
            OWSFailDebug(@"TSInfoMessageAddGroupToProfileWhitelistOffer");
            return nil;
        case TSInfoMessageTypeGroupUpdate:
            return nil;
        case TSInfoMessageTypeGroupQuit:
            return nil;
        case TSInfoMessageTypeDisappearingMessagesUpdate:
            return [SystemMessageAction actionWithTitle:NSLocalizedString(@"CONVERSATION_SETTINGS_TAP_TO_CHANGE",
                                                            @"Label for button that opens conversation settings.")
                                                  block:^{
                                                      [weakSelf.delegate showConversationSettings];
                                                  }];
    }

    OWSLogInfo(@"Unhandled tap for info message: %@", message);
    return nil;
}

#pragma mark - Events

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)longPress
{
    OWSAssertDebug(self.delegate);

    if ([self isGestureInCellHeader:longPress]) {
        return;
    }

    TSInteraction *interaction = self.viewItem.interaction;
    OWSAssertDebug(interaction);

    if (longPress.state == UIGestureRecognizerStateBegan) {
        [self.delegate conversationCell:self didLongpressSystemMessageViewItem:self.viewItem];
    }
}

- (BOOL)isGestureInCellHeader:(UIGestureRecognizer *)sender
{
    OWSAssertDebug(self.viewItem);

    if (!self.viewItem.hasCellHeader) {
        return NO;
    }

    CGPoint location = [sender locationInView:self];
    CGPoint headerBottom = [self convertPoint:CGPointMake(0, self.headerView.height) fromView:self.headerView];
    return location.y <= headerBottom.y;
}

- (void)buttonWasPressed:(id)sender
{
    if (!self.action.block) {
        OWSFailDebug(@"Missing action");
    } else {
        self.action.block();
    }
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];

    self.action = nil;
}

@end

NS_ASSUME_NONNULL_END
