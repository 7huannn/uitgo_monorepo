import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      const _FaqItem(
        question: 'Làm sao để liên hệ tài xế?',
        answer:
            'Sau khi đặt chuyến, bạn có thể gọi hoặc nhắn tin trực tiếp cho tài xế từ màn hình theo dõi.',
      ),
      const _FaqItem(
        question: 'Tôi muốn báo cáo sự cố',
        answer:
            'Vào mục Trợ giúp > Gửi phản hồi. Đội ngũ UITGo sẽ phản hồi bạn trong vòng 24 giờ.',
      ),
      const _FaqItem(
        question: 'UITGo có hỗ trợ hóa đơn doanh nghiệp?',
        answer:
            'Có, bạn có thể yêu cầu hóa đơn điện tử sau mỗi chuyến đi trong phần Lịch sử chuyến.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ giúp & Hỗ trợ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(Icons.support_agent, color: Color(0xFF667EEA)),
              ),
              title: const Text('Trung tâm hỗ trợ 24/7'),
              subtitle:
                  const Text('Gọi 1900-123-456 hoặc chat với UITGo Care.'),
              trailing: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Tính năng chat sẽ có trong bản chính thức.')),
                  );
                },
                child: const Text('Chat ngay'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Câu hỏi thường gặp',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...faqs.map(
            (faq) => ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              title: Text(
                faq.question,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(faq.answer),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Gửi phản hồi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Form phản hồi sẽ có sau khi backend hoàn tất.')),
              );
            },
            icon: const Icon(Icons.feedback_outlined),
            label: const Text('Gửi phản hồi cho UITGo'),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}
