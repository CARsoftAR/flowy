import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Failure hierarchy — all domain errors are expressed as typed Failures
// ─────────────────────────────────────────────────────────────────────────────

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

class StreamFailure extends Failure {
  final String? videoId;
  const StreamFailure(super.message, {this.videoId});
  @override
  List<Object?> get props => [message, videoId];
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache error']);
}

class YoutubeFailure extends Failure {
  const YoutubeFailure([super.message = 'YouTube extraction failed']);
}

class ParseFailure extends Failure {
  const ParseFailure([super.message = 'Data parsing failed']);
}

class UnknownFailure extends Failure {
  final Object? original;
  const UnknownFailure([super.message = 'Unknown error', this.original]);
  @override
  List<Object?> get props => [message, original];
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Database error']);
}

// ─────────────────────────────────────────────────────────────────────────────
// UseCase base class — enforces a clean, testable interface contract
// ─────────────────────────────────────────────────────────────────────────────

typedef FutureEither<T> = Future<Either<Failure, T>>;
typedef FutureEitherVoid = FutureEither<void>;

abstract class UseCase<T, Params> {
  FutureEither<T> call(Params params);
}

abstract class StreamUseCase<T, Params> {
  Stream<Either<Failure, T>> call(Params params);
}

class NoParams extends Equatable {
  const NoParams();
  @override
  List<Object?> get props => [];
}
