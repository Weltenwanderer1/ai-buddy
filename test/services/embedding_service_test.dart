import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_buddy/services/embedding_service.dart';

void main() {
  group('EmbeddingService', () {
    test('cosineSimilarity returns 1.0 for identical vectors', () {
      final vec = [1.0, 2.0, 3.0];
      expect(EmbeddingService.cosineSimilarity(vec, vec), closeTo(1.0, 0.001));
    });

    test('cosineSimilarity returns 0.0 for orthogonal vectors', () {
      final a = [1.0, 0.0, 0.0];
      final b = [0.0, 1.0, 0.0];
      expect(EmbeddingService.cosineSimilarity(a, b), closeTo(0.0, 0.001));
    });

    test('cosineSimilarity returns 0.0 for null vectors', () {
      expect(EmbeddingService.cosineSimilarity(null, [1.0]), 0.0);
      expect(EmbeddingService.cosineSimilarity([1.0], null), 0.0);
      expect(EmbeddingService.cosineSimilarity(null, null), 0.0);
    });

    test('cosineSimilarity returns 0.0 for empty vectors', () {
      expect(EmbeddingService.cosineSimilarity([], []), 0.0);
    });

    test('cosineSimilarity returns 0.0 for mismatched lengths', () {
      expect(EmbeddingService.cosineSimilarity([1.0, 2.0], [1.0]), 0.0);
    });

    test('getEmbedding returns embedding from API', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'nomic-embed-text');
        expect(body['prompt'], 'hello');
        return http.Response(
          jsonEncode({'embedding': [0.1, 0.2, 0.3]}),
          200,
        );
      });

      final service = EmbeddingService(
        baseUrl: 'http://localhost:11434',
        model: 'nomic-embed-text',
        client: mockClient,
      );
      final embedding = await service.getEmbedding('hello');

      expect(embedding, isNotNull);
      expect(embedding!.length, 3);
      expect(embedding[0], 0.1);
      expect(embedding[1], 0.2);
      expect(embedding[2], 0.3);

      mockClient.close();
    });

    test('getEmbedding uses cache on second call', () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({'embedding': [0.1, 0.2]}),
          200,
        );
      });

      final service = EmbeddingService(
        baseUrl: 'http://localhost:11434',
        model: 'nomic-embed-text',
        client: mockClient,
      );
      await service.getEmbedding('test');
      await service.getEmbedding('test');

      expect(requestCount, 1); // Only one API call due to caching

      mockClient.close();
    });

    test('getEmbedding returns null on API error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final service = EmbeddingService(
        baseUrl: 'http://localhost:11434',
        model: 'nomic-embed-text',
        client: mockClient,
      );
      final embedding = await service.getEmbedding('fail');

      expect(embedding, isNull);

      mockClient.close();
    });

    test('clearCache empties the cache', () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({'embedding': [0.1]}),
          200,
        );
      });

      final service = EmbeddingService(
        baseUrl: 'http://localhost:11434',
        model: 'nomic-embed-text',
        client: mockClient,
      );
      await service.getEmbedding('test');
      service.clearCache();
      await service.getEmbedding('test'); // Should trigger new API call

      expect(requestCount, 2);

      mockClient.close();
    });

    test('getEmbeddings batch returns multiple embeddings', () async {
      var count = 0;
      final mockClient = MockClient((request) async {
        count++;
        return http.Response(
          jsonEncode({'embedding': [count.toDouble()]}),
          200,
        );
      });

      final service = EmbeddingService(
        baseUrl: 'http://localhost:11434',
        model: 'nomic-embed-text',
        client: mockClient,
      );
      final embeddings = await service.getEmbeddings(['a', 'b']);

      expect(embeddings.length, 2);
      expect(embeddings['a'], [1.0]);
      expect(embeddings['b'], [2.0]);

      mockClient.close();
    });

    test('getEmbedding strips duplicate /api suffix from base URL', () async {
      Uri? seenUrl;
      final mockClient = MockClient((request) async {
        seenUrl = request.url;
        return http.Response(jsonEncode({'embedding': [0.1]}), 200);
      });

      final service = EmbeddingService(
        baseUrl: 'https://ollama.com/api', // App-Default endet auf /api
        model: 'nomic-embed-text',
        client: mockClient,
      );
      await service.getEmbedding('x');

      expect(seenUrl.toString(), 'https://ollama.com/api/embeddings');

      mockClient.close();
    });

    test('getEmbedding handles empty string', () async {
      final service = EmbeddingService(
        baseUrl: 'http://localhost:11434',
        model: 'nomic-embed-text',
      );
      final result = await service.getEmbedding('');
      expect(result, isNull);
    });
  });
}
