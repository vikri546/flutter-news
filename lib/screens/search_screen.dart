import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/error_view.dart';
import '../providers/article_provider.dart';

enum DateFilter {
  all,
  yesterday,
  lastWeek,
  lastMonth,
}

enum SortOrder {
  newest,
  oldest,
  relevance
}

class SearchScreen extends StatefulWidget {
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const SearchScreen({
    Key? key,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  final List<String> _searchRecommendations = [
    'Technology',
    'Business',
    'Health',
    'Sports',
    'Entertainment',
    'Science',
    'Politics',
    'World News',
  ];
  
  List<String> _searchHistory = [];
  bool _isTyping = false;
  
  DateFilter _selectedDateFilter = DateFilter.all;
  SortOrder _selectedSortOrder = SortOrder.newest;
  
  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();
    _searchController.addListener(_onSearchChanged);
    _loadSearchHistory();
  }
  
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }
  
  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }
  
  void _addToSearchHistory(String query) {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _searchHistory.remove(query);
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(0, 10);
      }
    });
    
    _saveSearchHistory();
  }
  
  void _clearSearchHistory() async {
    setState(() {
      _searchHistory.clear();
    });
    _saveSearchHistory();
  }
  
  void _onSearchChanged() {
    setState(() {
      _isTyping = _searchController.text.isNotEmpty;
    });
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  void _performSearch(String query) {
    if (query.trim().isNotEmpty) {
      _addToSearchHistory(query);
      Provider.of<ArticleProvider>(context, listen: false).searchArticles(
        query,
        dateFilter: _getDateFilterParams(),
        sortBy: _getSortOrderParams(),
      );
      FocusScope.of(context).unfocus();
    }
  }
  
  Map<String, dynamic> _getDateFilterParams() {
    final now = DateTime.now();
    DateTime? fromDate;
    
    switch (_selectedDateFilter) {
      case DateFilter.yesterday:
        fromDate = DateTime(now.year, now.month, now.day - 1);
        break;
      case DateFilter.lastWeek:
        fromDate = now.subtract(const Duration(days: 7));
        break;
      case DateFilter.lastMonth:
        fromDate = now.subtract(const Duration(days: 30));
        break;
      case DateFilter.all:
      default:
        break;
    }
    
    return {
      'from': fromDate?.toIso8601String(),
      'to': null,
    };
  }
  
  String _getSortOrderParams() {
    switch (_selectedSortOrder) {
      case SortOrder.newest:
        return 'publishedAt';
      case SortOrder.oldest:
        return 'publishedAt';
      case SortOrder.relevance:
        return 'relevancy';
    }
  }
  
  void _selectRecommendation(String recommendation) {
    _searchController.text = recommendation;
    _performSearch(recommendation);
  }

  String _getDateFilterDropdownLabel(DateFilter filter) {
    switch (filter) {
      case DateFilter.yesterday:
        return 'Yesterday';
      case DateFilter.lastWeek:
        return 'Last Week';
      case DateFilter.lastMonth:
        return 'Last Month';
      case DateFilter.all:
      default:
        return 'Date';
    }
  }

  String _getSortOrderDropdownLabel(SortOrder order) {
    switch (order) {
      case SortOrder.newest:
        return 'Newest';
      case SortOrder.oldest:
        return 'Oldest';
      case SortOrder.relevance:
        return 'Relevance';
    }
  }
  
  Widget _buildFilterButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = isDark ? Colors.grey[800] : Colors.grey[200];
    final selectedButtonColor = Theme.of(context).colorScheme.primary;
    final onSelectedColor = Theme.of(context).colorScheme.onPrimary;

    Widget buildDropdownButtonChild(String label, bool isSelected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedButtonColor : buttonColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? onSelectedColor : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: isSelected ? onSelectedColor : Theme.of(context).iconTheme.color,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Text(
            'Filter :',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),

          ActionChip(
            label: const Text('All Time'),
            onPressed: () {
              setState(() {
                _selectedDateFilter = DateFilter.all;
              });
              if (_searchController.text.isNotEmpty) {
                _performSearch(_searchController.text);
              }
            },
            backgroundColor: _selectedDateFilter == DateFilter.all ? selectedButtonColor : buttonColor,
            labelStyle: TextStyle(
              color: _selectedDateFilter == DateFilter.all ? onSelectedColor : Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w500,
            ),
            side: BorderSide.none,
          ),
          const SizedBox(width: 8),

          PopupMenuButton<DateFilter>(
            onSelected: (DateFilter result) {
              setState(() {
                _selectedDateFilter = result;
              });
              if (_searchController.text.isNotEmpty) {
                _performSearch(_searchController.text);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<DateFilter>>[
              const PopupMenuItem<DateFilter>(
                value: DateFilter.yesterday,
                child: Text('Yesterday'),
              ),
              const PopupMenuItem<DateFilter>(
                value: DateFilter.lastWeek,
                child: Text('Last Week'),
              ),
              const PopupMenuItem<DateFilter>(
                value: DateFilter.lastMonth,
                child: Text('Last Month'),
              ),
            ],
            child: buildDropdownButtonChild(
              _getDateFilterDropdownLabel(_selectedDateFilter),
              _selectedDateFilter != DateFilter.all,
            ),
          ),
          const SizedBox(width: 8),
          
          PopupMenuButton<SortOrder>(
            onSelected: (SortOrder result) {
              setState(() {
                _selectedSortOrder = result;
              });
              if (_searchController.text.isNotEmpty) {
                _performSearch(_searchController.text);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOrder>>[
              const PopupMenuItem<SortOrder>(
                value: SortOrder.newest,
                child: Text('Newest First'),
              ),
              const PopupMenuItem<SortOrder>(
                value: SortOrder.oldest,
                child: Text('Oldest First'),
              ),
              const PopupMenuItem<SortOrder>(
                value: SortOrder.relevance,
                child: Text('Most Relevant'),
              ),
            ],
            child: buildDropdownButtonChild(
              _getSortOrderDropdownLabel(_selectedSortOrder),
              false,
            ),
          ),
        ],
      ),
    );
  }
  
  List<Article> _filterAndSortArticles(List<Article> articles) {
    List<Article> filteredArticles = List.from(articles);
    
    if (_selectedDateFilter != DateFilter.all) {
      final now = DateTime.now();
      DateTime? cutoffDate;
      
      switch (_selectedDateFilter) {
        case DateFilter.yesterday:
          cutoffDate = DateTime(now.year, now.month, now.day - 1);
          break;
        case DateFilter.lastWeek:
          cutoffDate = now.subtract(const Duration(days: 7));
          break;
        case DateFilter.lastMonth:
          cutoffDate = now.subtract(const Duration(days: 30));
          break;
        default:
          break;
      }
      
      if (cutoffDate != null) {
        filteredArticles = filteredArticles.where((article) {
          final publishedAt = article.publishedAt;
          return publishedAt != null && publishedAt.isAfter(cutoffDate!);
        }).toList();
      }
    }
    
    switch (_selectedSortOrder) {
      case SortOrder.newest:
        filteredArticles.sort((a, b) {
          if (a.publishedAt == null && b.publishedAt == null) return 0;
          if (a.publishedAt == null) return 1;
          if (b.publishedAt == null) return -1;
          return b.publishedAt!.compareTo(a.publishedAt!);
        });
        break;
      case SortOrder.oldest:
        filteredArticles.sort((a, b) {
          if (a.publishedAt == null && b.publishedAt == null) return 0;
          if (a.publishedAt == null) return 1;
          if (b.publishedAt == null) return -1;
          return a.publishedAt!.compareTo(b.publishedAt!);
        });
        break;
      case SortOrder.relevance:
        break;
    }
    
    return filteredArticles;
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Search for news...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
            ),
          ),
          style: Theme.of(context).textTheme.bodyLarge,
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
        ),
        actions: [
          if (_isTyping)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                Provider.of<ArticleProvider>(context, listen: false).clearSearch();
              },
            ),
        ],
      ),
      body: Consumer<ArticleProvider>(
        builder: (context, articleProvider, child) {
          final status = articleProvider.searchStatus;
          final results = articleProvider.searchResults;
          
          if (status == ArticleLoadingStatus.initial && !_isTyping) {
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              children: [
                if (_searchHistory.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Searches',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: _clearSearchHistory,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _searchHistory.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(_searchHistory[index]),
                        onTap: () => _selectRecommendation(_searchHistory[index]),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      );
                    },
                  ),
                  const Divider(thickness: 1, height: 24),
                ],
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                  child: Text(
                    'Recommended Searches',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _searchRecommendations.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.trending_up),
                      title: Text(_searchRecommendations[index]),
                      onTap: () => _selectRecommendation(_searchRecommendations[index]),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  },
                ),
              ],
            );
          } else if (status == ArticleLoadingStatus.initial) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search for news',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          } else if (status == ArticleLoadingStatus.loading) {
            return Column(
              children: [
                _buildFilterButtons(),
                const Divider(height: 1),
                Expanded(child: ShimmerLoading(isDark: isDark)),
              ],
            );
          } else if (status == ArticleLoadingStatus.error) {
            return Column(
              children: [
                _buildFilterButtons(),
                const Divider(height: 1),
                Expanded(
                  child: ErrorView(
                    message: articleProvider.errorMessage,
                    onRetry: () => _performSearch(_searchController.text),
                  ),
                ),
              ],
            );
          } else if (results.isEmpty) {
            return Column(
              children: [
                _buildFilterButtons(),
                const Divider(height: 1),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters or search terms',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          
          final filteredResults = _filterAndSortArticles(results);
          
          return Column(
            children: [
              _buildFilterButtons(),
              const Divider(height: 1),
              if (filteredResults.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    '${filteredResults.length} result${filteredResults.length != 1 ? 's' : ''} found',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                ),
              Expanded(
                child: filteredResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.filter_list_off,
                              size: 64,
                              color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results match your filters',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your date range or sort options',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredResults.length,
                        itemBuilder: (context, index) {
                          final article = filteredResults[index];
                          final isBookmarked = widget.bookmarkedArticles.any((a) => a.url == article.url);
                          
                          return ArticleCard(
                            article: article,
                            isBookmarked: isBookmarked,
                            onBookmarkToggle: () => widget.onBookmarkToggle(article),
                            index: index,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
