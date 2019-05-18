import 'dart:async';

import 'package:awesome_dev/api/articles.dart';
import 'package:awesome_dev/ui/widgets/article_widget.dart';
import 'package:flutter/material.dart';
import 'package:awesome_dev/ext/flutter_calendar.dart'
    as awesome_dev_flutter_calendar;
import 'package:shared_preferences/shared_preferences.dart';

enum IndicatorType { overscroll, refresh }

class ArticleArchives extends StatefulWidget {
  const ArticleArchives();

  @override
  State<StatefulWidget> createState() => ArticleArchivesState();
}

class ArticleArchivesState extends State<ArticleArchives> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool _initialDisplay = true;
  List<Article> _articles;
  DateTime _currentDate = DateTime.now();
  Exception _errorOnLoad;

  Future<Null> _onRefresh() async => _fetchArticles(_currentDate);

  Future<Null> _fetchArticles(DateTime date) async {
    final articlesClient = ArticlesClient();
    try {
      final dateSlug = "${date.year.toString()}-"
          "${date.month.toString().padLeft(2,'0')}-"
          "${date.day.toString().padLeft(2,'0')}";
      final filteredArticles =
          await articlesClient.getArticlesForDate(dateSlug);
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList("favs") ?? [];
      for (var article in filteredArticles) {
        article.starred =
            favorites.contains(article.toSharedPreferencesString());
      }
      setState(() {
        _initialDisplay = false;
        _currentDate = date;
        _articles = filteredArticles;
        _errorOnLoad = null;
      });
    } on Exception catch (e) {
      setState(() {
        _initialDisplay = false;
        _currentDate = date;
        _articles = null;
        _errorOnLoad = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialDisplay) {
      final widget = Stack(
        children: <Widget>[
          Center(
            child: CircularProgressIndicator(),
          ),
          Center(child: Text("Please hold on - loading articles..."))
        ],
      );
      _onRefresh();
      return widget;
    }

    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _onRefresh,
      child: Container(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.topCenter,
              child: awesome_dev_flutter_calendar.Calendar(
                isExpandable: true,
                onDateSelected: (selectedDateTime) {
                  _currentDate = selectedDateTime;
                  _refreshIndicatorKey.currentState.show();
                },
              ),
            ),
            Container(
                child: Expanded(
                    child: Scrollbar(
                        child: ListView.builder(
              padding: EdgeInsets.all(8.0),
              itemCount: _errorOnLoad != null
                  ? 1
                  : (_articles == null || _articles.isEmpty)
                      ? 1
                      : _articles.length,
              itemBuilder: (BuildContext context, int index) {
                if (_errorOnLoad != null) {
                  return Center(
                    child: Text(
                      "Internal error: ${_errorOnLoad.toString()}",
                      style: TextStyle(color: Colors.red, fontSize: 20.0),
                    ),
                  );
                }
                if (_articles == null || _articles.isEmpty) {
                  return Center(
                    child: Text(
                      "No article found at this time",
                      style: TextStyle(fontSize: 20.0),
                    ),
                  );
                }
                return ArticleWidget(
                  article: _articles[index],
                  onStarClick: () {
                    setState(() {
                      _articles[index].starred = !_articles[index].starred;
                    });
                  },
                );
              },
            )))),
          ],
        ),
      ),
    );
  }
}