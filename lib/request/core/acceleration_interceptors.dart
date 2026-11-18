import 'package:dio/dio.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/ech_adapter.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';
import 'package:kazumi/services/network/rules_mirror.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';

class BangumiAccelerationInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = options.uri;
    if (ApiEndpoints.bangumiPublicApiHosts.contains(uri.host)) {
      switch (BangumiAcceleration.current) {
        case BangumiAcceleration.direct:
          break;
        case BangumiAcceleration.ech:
          options.path = uri.replace(scheme: 'https').toString();
          options.queryParameters = {};
          options.requireEch();
        case BangumiAcceleration.mirror:
          final searchPath = ApiEndpoints.bangumiRankSearch.split('?').first;
          final hasMirrorCredentials =
              bangumiMirrorCredentials.values.every((value) => value.isNotEmpty);
          // Unsigned search requests are rejected by the mirror.
          if (uri.path == searchPath && !hasMirrorCredentials) break;
          options.path =
              ApiEndpoints.bangumiMirrorDomain +
              uri.path +
              (uri.hasQuery ? '?${uri.query}' : '');
          options.queryParameters = {};
      }
    }
    handler.next(options);
  }
}

class RulesMirrorInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final url = options.uri.toString();
    if (url.startsWith(ApiEndpoints.pluginShop)) {
      switch (RulesMirror.current) {
        case RulesMirror.direct:
          break;
        case RulesMirror.ghProxy:
          options.path = ApiEndpoints.ghProxyMirror + url;
          options.requireEch();
        case RulesMirror.ghfast:
          options.path = ApiEndpoints.ghfastMirror + url;
        case RulesMirror.gitcode:
          options.path =
              ApiEndpoints.gitcodeMirror +
              url.substring(ApiEndpoints.pluginShop.length);
      }
    }
    handler.next(options);
  }
}
