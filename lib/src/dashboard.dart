import 'dart:typed_data';

import 'package:dashboard_grid/src/table/table_span.dart';
import 'package:flutter/material.dart';

import 'common/constants.dart';
import 'common/span.dart';
import 'dashboard_grid.dart';
import 'dashboard_widget.dart';
import 'table/table.dart';
import 'table/table_cell.dart';
import 'table/table_cell_decoration.dart';
import 'package:screenshot/screenshot.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({
    super.key,
    this.editMode = false,
    required this.config,
    this.cellPreviewDecoration = const TableCellDecoration(),
    this.controller,
  });

  final bool editMode;
  final DashboardGrid config;
  final TableCellDecoration cellPreviewDecoration;
  final DashboardController? controller;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final yController = ScrollController();
  final xController = ScrollController();

  DashboardGrid? originalConfig;
  ScreenshotController screenshotController = ScreenshotController();

  @override
  void initState() {
    widget.config.addListener(_configListener);

    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.config.removeListener(_configListener);
    yController.dispose();
    xController.dispose();

    super.dispose();
  }

  void _configListener() {
    setState(() {});
  }

  Future<Uint8List?> getPngBytes(BuildContext context) async {
    // Calculate the dynamic size based on the dashboard configuration
    final double totalWidth = widget.config.maxColumns * kWidgetWidth +
        (widget.config.maxColumns - 1) * kWidgetSpacing;
    final double totalHeight = widget.config.currentHeight * kWidgetHeight +
        (widget.config.currentHeight - 1) * kWidgetSpacing;

    return await screenshotController.captureFromWidget(
      Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) => _buildLongDashboard(context),
          ),
        ],
      ),
      context: context,
      targetSize: Size(totalWidth + 35, totalHeight + 35), // extra added for padding
      delay: const Duration(milliseconds: 100),
      pixelRatio: 2.0,
    );
  }


  @override
  void didUpdateWidget(covariant Dashboard oldWidget) {
    if (oldWidget.config != widget.config) {
      oldWidget.config.removeListener(_configListener);
      widget.config.addListener(_configListener);
    }

    if (oldWidget.editMode != widget.editMode) {
      setState(() {
        if (widget.editMode) {
          // Do. copy of original config
          originalConfig = widget.config.copy();
        } else {
          // Do. restore original config
          if (originalConfig != null) {
            originalConfig = null;
          }
        }
      });
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return _buildDashboard(context);
  }

  TableViewCell? _findBestCellMatch(TableVicinity vicinity) {
    final config = widget.config.getWidgetAt(vicinity.xIndex, vicinity.yIndex);
    if (config == null) return null;

    BoxConstraints constraints = BoxConstraints.expand(
      width: kWidgetWidth * config.width + kWidgetSpacing * (config.width - 1),
      height:
      kWidgetHeight * config.height + kWidgetSpacing * (config.height - 1),
    );

    final child =
    widget.editMode
        ? Draggable(
      data: config,
      feedback: Opacity(
        opacity: 0.5,
        child: ConstrainedBox(
          constraints: constraints,
          child: config.builder(context),
        ),
      ),
      childWhenDragging: Container(),
      child: DragTarget<DashboardWidget>(
        builder: (context, candidate, rejected) {
          return config.builder(context);
        },
        onAcceptWithDetails: (details) {
          try {
            widget.config.moveWidget(
              details.data.id,
              vicinity.xIndex,
              vicinity.yIndex,
            );
          } on NotEnoughSpaceException {
            // Oops
          } catch (e) {
            rethrow;
          }

          setState(() {});
        },
      ),
      onDragUpdate: (details) {
        // Update details
        // print(details.localPosition);
      },
    )
        : config.builder(context);

    return TableViewCell(
      columnMergeStart: config.x,
      columnMergeSpan: config.width,
      child: child,
    );
  }

  TableSpan _buildColumnSpan(int index) {
    return TableSpan(
      // backgroundDecoration:
      //     widget.editMode
      //         ? SpanDecoration(
      //           color: Colors.red.withAlpha(100),
      //           consumeSpanPadding: false,
      //         )
      //         : null,
      padding: SpanPadding(
        leading: kWidgetSpacing,
        trailing: widget.config.maxColumns - 1 == index ? kWidgetSpacing : 0.0,
      ),
      extent: const FixedTableSpanExtent(kWidgetWidth),
    );
  }

  TableSpan _buildRowSpan(int index) {
    return TableSpan(
      padding: SpanPadding(
        leading: kWidgetSpacing,
        trailing:
        widget.config.currentHeight - 1 == index ? kWidgetSpacing : 0.0,
      ),
      // backgroundDecoration:
      //     widget.editMode
      //         ? SpanDecoration(
      //           color: Colors.green.withAlpha(100),
      //           consumeSpanPadding: false,
      //         )
      //         : null,
      extent: const FixedTableSpanExtent(kWidgetHeight),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    return Scrollbar(
      trackVisibility: true,
      thumbVisibility: true,
      scrollbarOrientation: ScrollbarOrientation.right,
      controller: yController,
      child: Scrollbar(
        trackVisibility: true,
        thumbVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        controller: xController,
        child: TableView.builder(
          columnCount: widget.config.maxColumns,
          rowCount: widget.config.currentHeight,
          verticalDetails: ScrollableDetails.vertical(controller: yController),
          horizontalDetails: ScrollableDetails.horizontal(
            controller: xController,
          ),
          cellBuilder: (BuildContext context, TableVicinity vicinity) {
            final cell = _findBestCellMatch(vicinity);
            if (cell != null) {
              return cell;
            } else {
              // Empty space
              if (widget.editMode) {
                return TableViewCell(
                  child: DragTarget<DashboardWidget>(
                    builder: (context, accepted, rejected) {
                      return Container();
                    },
                    onAcceptWithDetails: (details) {
                      try {
                        widget.config.moveWidget(
                          details.data.id,
                          vicinity.xIndex,
                          vicinity.yIndex,
                        );
                      } on NotEnoughSpaceException {
                        // Oops
                      } catch (e) {
                        rethrow;
                      }

                      setState(() {});
                    },
                  ),
                );
              } else {
                return const TableViewCell(child: SizedBox.shrink());
              }
            }
          },
          columnBuilder: _buildColumnSpan,
          rowBuilder: _buildRowSpan,
          cellDecoration: widget.cellPreviewDecoration,
          editMode: widget.editMode,
        ),
      ),
    );
  }

  Widget _buildLongDashboard(BuildContext context) {
    return Material(
      child: InheritedTheme.captureAll(
        context,
        _buildDashboard(context),
      ),
    );
  }

}

class DashboardController {
  late _DashboardState _state;

  void _attach(_DashboardState state) {
    _state = state;
  }

  Future<Uint8List?> getPngBytes(BuildContext context) async {
    return _state.getPngBytes(context);
  }
}