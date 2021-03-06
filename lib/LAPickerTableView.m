/*
 
 LAPickerTableView.m
 LAPickerView
 
 Copyright (cc) 2012 Luis Laugga.
 Some rights reserved, all wrongs deserved.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 */

#import "LAPickerTableView.h"

@implementation LAPickerTableView

@synthesize selectedColumn=_selectedColumn;

@synthesize dataSource=_dataSource;
@synthesize delegate=_delegate;

#define kColumnOpacity 0.35
#define kSelectedColumnOpacity 1.0

#define kSelectionAlignmentAnimationDuration 0.25

#pragma mark -
#pragma mark Initialization

#if !__has_feature(objc_arc)
- (void)dealloc
{
    if(_columns)
        [_columns release];
    
    [_scrollView release];
    [super dealloc];
}
#endif

- (id)initWithFrame:(CGRect)frame andComponent:(NSInteger)component
{
    self = [super initWithFrame:frame];
    if(self)
    {
        // State
        _component = component;
        _selectedColumn = -1; // none selected, default
        _highlightedColumn = -1; // none highlighted, default
        
        // View
        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.delegate = self;
        [self addSubview:_scrollView];
        
        // Layout
        _columnSize = CGSizeMake(60, frame.size.height);
    }
    return self;
}

#pragma mark -
#pragma mark Layout

- (void)layoutSubviews
{
    PrettyLog;
    
    if(_columns == nil)
    {
        [self reloadData];
    }
}

- (void)updateScrollViewAnimated:(BOOL)animated
{
    if(_numberOfColumns > 0)
    {
        if(animated)
        {
            [UIView animateWithDuration:kSelectionAlignmentAnimationDuration animations:^{
                
                // Update scroll view
                _scrollView.contentInset = UIEdgeInsetsMake(0, _selectionEdgeInset, 0, 0);
                _scrollView.contentSize = CGSizeMake(_contentSize+_contentSizePadding, _columnSize.height);
                
            } completion:^(BOOL finished){
                
                // Update selected column
                [self setSelectedColumn:_selectedColumn animated:animated];
                
            }];
        }
        else
        {
            // Update scroll view
            _scrollView.contentInset = UIEdgeInsetsMake(0, _selectionEdgeInset, 0, 0);
            _scrollView.contentSize = CGSizeMake(_contentSize+_contentSizePadding, _columnSize.height);
            
            // Update selected column
            [self setSelectedColumn:_selectedColumn animated:animated];
        }
    }
}

- (void)setSelectedColumn:(NSInteger)column animated:(BOOL)animated
{
    Log(@"setSelectedColumn: %d", column);
    
    if(_numberOfColumns)
    {
        // Range is [0, numberOfColumns]
        if(column > -1 && column < _numberOfColumns)
        {
            _contentOffset = column*_columnSize.width;
            _selectedColumn = column;
            
            [_scrollView setContentOffset:CGPointMake(-_selectionEdgeInset+_contentOffset, 0) animated:animated];
        }
    }
}

- (void)setSelectionAlignment:(LAPickerSelectionAlignment)selectionAlignment
{
    [self setSelectionAlignment:selectionAlignment animated:NO];
}

- (void)setSelectionAlignment:(LAPickerSelectionAlignment)selectionAlignment animated:(BOOL)animated
{
    // Assign
    _selectionAlignment = selectionAlignment;
    
    // Update layout
    switch (_selectionAlignment)
    {
        case LAPickerSelectionAlignmentLeft:
        {
            _selectionEdgeInset = 0.0;
            _contentSizePadding = _scrollView.frame.size.width-_columnSize.width;
            
        }
            break;
        case LAPickerSelectionAlignmentRight:
        {
            _selectionEdgeInset = self.frame.size.width-_columnSize.width;
            _contentSizePadding = 0.0;
        }
            break;
        case LAPickerSelectionAlignmentCenter:
        default:
        {
            _selectionEdgeInset = self.frame.size.width/2.0f-_columnSize.width/2.0;
            _contentSizePadding = _selectionEdgeInset;
        }
            break;
    }
    
    // Recalculate and correct non-integer values
    _selectionEdgeInset = floorf(_selectionEdgeInset);
    _contentSizePadding = floorf(_contentSizePadding);
    _selectionOffsetDelta = _selectionEdgeInset + _columnSize.width/2.0;
    
    // Update scroll view
    [self updateScrollViewAnimated:animated];
}

- (void)setHighlightedColumn:(NSInteger)highlightedColumn
{
    // Range is [0, _numberOfColumns-1]
    highlightedColumn = MIN(highlightedColumn, _maxSelectionRange);
    highlightedColumn = MAX(0, highlightedColumn);
    
    // Selected column is different
    if(highlightedColumn != _highlightedColumn)
    {
        if(_highlightedColumn > -1) // Previous highlighted
        {
            UILabel * previousHighlightedColumn = [_columns objectAtIndex:_highlightedColumn];
            UILabel * nextHighlightedColumn = [_columns objectAtIndex:highlightedColumn];
            
            previousHighlightedColumn.layer.opacity = kColumnOpacity;
            nextHighlightedColumn.layer.opacity = kSelectedColumnOpacity;
        }
        else // No previous selection
        {
            UILabel * nextHighlightedColumn = [_columns objectAtIndex:highlightedColumn];
            nextHighlightedColumn.layer.opacity = kSelectedColumnOpacity;
        }
        
        // Assign new value
        _highlightedColumn = highlightedColumn;
        
        // Notify delegate
        [_delegate pickerTableView:self didHighlightColumn:highlightedColumn inComponent:_component];
    }
}

#pragma mark -
#pragma mark Data

- (void)reloadData
{
    // Set number of columns to 0
    _numberOfColumns = 0;
    
    // Clean up
    [_columns removeAllObjects];
    [_scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_scrollView setContentSize:CGSizeZero];
    
    if(_dataSource)
    {
        _numberOfColumns = [_dataSource pickerTableView:self numberOfColumnsInComponent:_component];
        _columns = [[NSMutableArray alloc] initWithCapacity:_numberOfColumns];
        _maxSelectionRange = _numberOfColumns-1;
        
        if(_delegate)
        {
            NSMutableArray * columnViews = [[NSMutableArray alloc] initWithCapacity:_numberOfColumns];
            CGSize columnSize = CGSizeZero;
            
            for(int column=0; column<_numberOfColumns; ++column)
            {
                UIView * view = [_delegate pickerTableView:self viewForColumn:column forComponent:_component reusingView:nil];
                NSString * title = [_delegate pickerTableView:self titleForColumn:column forComponent:_component];
                
                if(view == nil)
                {
                    UILabel * label = [[UILabel alloc] init];
                    label.textColor = [UIColor blackColor];
                    label.text = title;
                    label.textAlignment = UITextAlignmentCenter;
                    label.backgroundColor = [UIColor clearColor];
                    
                    [label sizeToFit];
                    
                    view = label;
                }
                else if(title != nil && [view isKindOfClass:[UILabel class]])
                {
                    [((UILabel *)view) setText:title];
                    [((UILabel *)view) sizeToFit];
                }
                
                columnSize.width = MAX(columnSize.width, view.frame.size.width);
                columnSize.height = MAX(columnSize.height, view.frame.size.height);
                
                [columnViews addObject:view];
            }
            
            _columnSize = columnSize;
            
            for(int column=0; column<_numberOfColumns; ++column)
            {
                UIView * view = [columnViews objectAtIndex:column];
                
                view.frame = CGRectMake(_contentSize, 0, _columnSize.width, _columnSize.height);
                view.layer.opacity = kColumnOpacity;
                
                [_columns addObject:view];
                [_scrollView addSubview:view];
                
                _contentSize += _columnSize.width;
            }
            
            
            // content size
            _scrollView.contentSize = CGSizeMake(_contentSize+_contentSizePadding, _columnSize.height);
        }
        
        // Update selected column
        [self setSelectionAlignment:_selectionAlignment];
        [self setSelectedColumn:0 animated:NO];
    }
}

#pragma mark -
#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Ignore if empty
    if(_numberOfColumns > 0)
    {
        // Calculate highlighted column
        NSInteger highlightedColumn = (NSInteger)((scrollView.contentOffset.x+_selectionOffsetDelta)/_columnSize.width);
        
        // Change highlighted column
        [self setHighlightedColumn:highlightedColumn];
    }
}

//- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
//{
//    PrettyLog;
//}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    // Ignore if empty
    if(_numberOfColumns > 0)
    {
        // Calculate selected column
        NSInteger targetSelectedColumn = (NSInteger)((targetContentOffset->x+_selectionOffsetDelta)/_columnSize.width);
        
        // Range is [0, _numberOfColumns-1]
        targetSelectedColumn = MIN(targetSelectedColumn, _maxSelectionRange);
        targetSelectedColumn = MAX(0, targetSelectedColumn);
        
        // Calculate contentOffset
        CGFloat targetContentOffsetX = targetSelectedColumn*_columnSize.width;
        
        // Change targetContentOffset
        targetContentOffset->x = -_selectionEdgeInset+targetContentOffsetX;
    }
}

//- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
//{
//    PrettyLog;
//}

//- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView
//{
//    PrettyLog;
//}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    // Calculate selected column
    NSInteger selectedColumn = (NSInteger)((scrollView.contentOffset.x+_selectionOffsetDelta)/_columnSize.width);
    
    // Range is [0, _numberOfColumns-1]
    selectedColumn = MIN(selectedColumn, _maxSelectionRange);
    selectedColumn = MAX(0, selectedColumn);
    
    if(selectedColumn != _selectedColumn)
    {
        if(selectedColumn > -1 && selectedColumn < _numberOfColumns)
        {
            // Assign new value
            _selectedColumn = selectedColumn;
            
            // Notify delegate
            if(_delegate && [_delegate respondsToSelector:@selector(pickerTableView:didSelectColumn:inComponent:)])
                [_delegate pickerTableView:self didSelectColumn:_selectedColumn inComponent:_component];
        }
    }
}

//- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
//{
//    PrettyLog;
//}

@end
