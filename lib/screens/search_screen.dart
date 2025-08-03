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
  lastHour,
  last2Hours,
  last3Hours,
  last6Hours,
  last12Hours,
  last24Hours,
  lastWeek,
  lastMonth,
  custom
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
  
  // List of search recommendations
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
  
  // List to store search history
  List<String> _searchHistory = [];
  
  // Track if user has started typing
  bool _isTyping = false;
  
  // Filter and sort options
  DateFilter _selectedDateFilter = DateFilter.all;
  SortOrder _selectedSortOrder = SortOrder.newest;
  DateTime? _customFromDate;
  DateTime? _customToDate;
  bool _showFilters = false;
  
  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();
    _searchController.addListener(_onSearchChanged);
    _loadSearchHistory();
  }
  
  // Load search history from SharedPreferences
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }
  
  // Save search history to SharedPreferences
  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }
  
  // Add a search term to history
  void _addToSearchHistory(String query) {
    if (query.trim().isEmpty) return;
    
    setState(() {
      // Remove the query if it already exists to avoid duplicates
      _searchHistory.remove(query);
      // Add the query to the beginning of the list
      _searchHistory.insert(0, query);
      // Limit history to 10 items
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(0, 10);
      }
    });
    
    _saveSearchHistory();
  }
  
  // Clear search history
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
      // Hide keyboard after search
      FocusScope.of(context).unfocus();
    }
  }
  
  Map<String, dynamic> _getDateFilterParams() {
    final now = DateTime.now();
    DateTime? fromDate;
    DateTime? toDate;
    
    switch (_selectedDateFilter) {
      case DateFilter.lastHour:
        fromDate = now.subtract(const Duration(hours: 1));
        break;
      case DateFilter.last2Hours:
        fromDate = now.subtract(const Duration(hours: 2));
        break;
      case DateFilter.last3Hours:
        fromDate = now.subtract(const Duration(hours: 3));
        break;
      case DateFilter.last6Hours:
        fromDate = now.subtract(const Duration(hours: 6));
        break;
      case DateFilter.last12Hours:
        fromDate = now.subtract(const Duration(hours: 12));
        break;
      case DateFilter.last24Hours:
        fromDate = now.subtract(const Duration(days: 1));
        break;
      case DateFilter.lastWeek:
        fromDate = now.subtract(const Duration(days: 7));
        break;
      case DateFilter.lastMonth:
        fromDate = now.subtract(const Duration(days: 30));
        break;
      case DateFilter.custom:
        fromDate = _customFromDate;
        toDate = _customToDate;
        break;
      case DateFilter.all:
      default:
        break;
    }
    
    return {
      'from': fromDate?.toIso8601String(),
      'to': toDate?.toIso8601String(),
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
  
  String _getDateFilterLabel(DateFilter filter) {
    switch (filter) {
      case DateFilter.all:
        return 'All Time';
      case DateFilter.lastHour:
        return 'Last Hour';
      case DateFilter.last2Hours:
        return 'Last 2 Hours';
      case DateFilter.last3Hours:
        return 'Last 3 Hours';
      case DateFilter.last6Hours:
        return 'Last 6 Hours';
      case DateFilter.last12Hours:
        return 'Last 12 Hours';
      case DateFilter.last24Hours:
        return 'Last 24 Hours';
      case DateFilter.lastWeek:
        return 'Last Week';
      case DateFilter.lastMonth:
        return 'Last Month';
      case DateFilter.custom:
        return 'Custom Range';
    }
  }
  
  String _getSortOrderLabel(SortOrder order) {
    switch (order) {
      case SortOrder.newest:
        return 'Newest First';
      case SortOrder.oldest:
        return 'Oldest First';
      case SortOrder.relevance:
        return 'Most Relevant';
    }
  }
  
  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _customFromDate != null && _customToDate != null
          ? DateTimeRange(start: _customFromDate!, end: _customToDate!)
          : null,
    );
    
    if (picked != null) {
      setState(() {
        _customFromDate = picked.start;
        _customToDate = picked.end;
        _selectedDateFilter = DateFilter.custom;
      });
      
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      }
    }
  }
  
  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(_showFilters ? Icons.expand_less : Icons.expand_more),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 8),
            // Date Filter
            Text(
              'Date Range',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: DateFilter.values.map((filter) {
                return FilterChip(
                  label: Text(_getDateFilterLabel(filter)),
                  selected: _selectedDateFilter == filter,
                  onSelected: (selected) {
                    if (filter == DateFilter.custom) {
                      _selectCustomDateRange();
                    } else {
                      setState(() {
                        _selectedDateFilter = filter;
                      });
                      if (_searchController.text.isNotEmpty) {
                        _performSearch(_searchController.text);
                      }
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Sort Order
            Text(
              'Sort By',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: SortOrder.values.map((order) {
                return FilterChip(
                  label: Text(_getSortOrderLabel(order)),
                  selected: _selectedSortOrder == order,
                  onSelected: (selected) {
                    setState(() {
                      _selectedSortOrder = order;
                    });
                    if (_searchController.text.isNotEmpty) {
                      _performSearch(_searchController.text);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // Clear Filters Button
            if (_selectedDateFilter != DateFilter.all || _selectedSortOrder != SortOrder.newest)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedDateFilter = DateFilter.all;
                    _selectedSortOrder = SortOrder.newest;
                    _customFromDate = null;
                    _customToDate = null;
                  });
                  if (_searchController.text.isNotEmpty) {
                    _performSearch(_searchController.text);
                  }
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
              ),
          ],
        ],
      ),
    );
  }
  
  List<Article> _filterAndSortArticles(List<Article> articles) {
    List<Article> filteredArticles = List.from(articles);
    
    // Apply date filter
    if (_selectedDateFilter != DateFilter.all) {
      final now = DateTime.now();
      DateTime? cutoffDate;
      
      switch (_selectedDateFilter) {
        case DateFilter.lastHour:
          cutoffDate = now.subtract(const Duration(hours: 1));
          break;
        case DateFilter.last2Hours:
          cutoffDate = now.subtract(const Duration(hours: 2));
          break;
        case DateFilter.last3Hours:
          cutoffDate = now.subtract(const Duration(hours: 3));
          break;
        case DateFilter.last6Hours:
          cutoffDate = now.subtract(const Duration(hours: 6));
          break;
        case DateFilter.last12Hours:
          cutoffDate = now.subtract(const Duration(hours: 12));
          break;
        case DateFilter.last24Hours:
          cutoffDate = now.subtract(const Duration(days: 1));
          break;
        case DateFilter.lastWeek:
          cutoffDate = now.subtract(const Duration(days: 7));
          break;
        case DateFilter.lastMonth:
          cutoffDate = now.subtract(const Duration(days: 30));
          break;
        case DateFilter.custom:
          if (_customFromDate != null && _customToDate != null) {
            filteredArticles = filteredArticles.where((article) {
              final publishedAt = article.publishedAt;
              if (publishedAt == null) return false;
              return publishedAt.isAfter(_customFromDate!) && 
                     publishedAt.isBefore(_customToDate!.add(const Duration(days: 1)));
            }).toList();
          }
          break;
        default:
          break;
      }
      
      if (cutoffDate != null && _selectedDateFilter != DateFilter.custom) {
        filteredArticles = filteredArticles.where((article) {
          final publishedAt = article.publishedAt;
          return publishedAt != null && publishedAt.isAfter(cutoffDate!);
        }).toList();
      }
    }
    
    // Apply sorting
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
        // Keep original order for relevance (as returned by API)
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
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(_searchController.text),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              Provider.of<ArticleProvider>(context, listen: false).clearSearch();
              setState(() {
                _isTyping = false;
              });
            },
          ),
        ],
      ),
      body: Consumer<ArticleProvider>(
        builder: (context, articleProvider, child) {
          final status = articleProvider.searchStatus;
          final results = articleProvider.searchResults;
          
          // Show recommendations and history if we're in initial state and not typing
          if (status == ArticleLoadingStatus.initial && !_isTyping) {
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              children: [
                // Search History Section
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
                        trailing: IconButton(
                          icon: const Icon(Icons.north_west),
                          onPressed: () => _selectRecommendation(_searchHistory[index]),
                          tooltip: 'Use this search',
                        ),
                        onTap: () => _selectRecommendation(_searchHistory[index]),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      );
                    },
                  ),
                  const Divider(thickness: 1, height: 24),
                ],
                
                // Recommended Searches Section
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
                _buildFilterChips(),
                const Divider(height: 1),
                Expanded(child: ShimmerLoading(isDark: isDark)),
              ],
            );
          } else if (status == ArticleLoadingStatus.error) {
            return Column(
              children: [
                _buildFilterChips(),
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
                _buildFilterChips(),
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
          
          // Filter and sort the results
          final filteredResults = _filterAndSortArticles(results);
          
          return Column(
            children: [
              _buildFilterChips(),
              const Divider(height: 1),
              // Results count
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
                          final isBookmarked = widget.bookmarkedArticles.contains(article);
                          
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
