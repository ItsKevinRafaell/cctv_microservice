# core/models.py
import torch
import torch.nn as nn


class TemporalAttention(nn.Module):
    def __init__(self, hidden_dim: int):
        super().__init__()
        self.att = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.Tanh(),
            nn.Linear(hidden_dim // 2, 1),
        )
        self.softmax = nn.Softmax(dim=1)

    def forward(self, lstm_output: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        # lstm_output: (batch, seq_len, hidden_dim)
        scores = self.att(lstm_output)  # (batch, seq_len, 1)
        weights = self.softmax(scores)  # softmax over time
        context = torch.sum(weights * lstm_output, dim=1)  # (batch, hidden_dim)
        return context, weights.squeeze(-1)


class YoloLSTM(nn.Module):
    """
    Bidirectional LSTM with temporal attention trained on 106-dim features per frame.
    Input expected shape: (batch, seq_len, feature_dim=106).
    """

    def __init__(
        self,
        feature_dim: int = 106,
        hidden_size: int = 384,
        num_layers: int = 2,
        dropout: float = 0.3,
    ):
        super().__init__()
        self.feature_dim = feature_dim
        self.hidden_size = hidden_size
        self.num_layers = num_layers

        self.lstm = nn.LSTM(
            input_size=feature_dim,
            hidden_size=hidden_size,
            num_layers=num_layers,
            batch_first=True,
            dropout=dropout,
            bidirectional=True,
        )

        att_dim = hidden_size * 2
        self.attn = TemporalAttention(att_dim)
        self.fc = nn.Sequential(
            nn.Linear(att_dim * 3, att_dim),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(att_dim, 1),
        )
        self.sigmoid = nn.Sigmoid()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: (batch, seq_len, feature_dim)
        lstm_out, _ = self.lstm(x)  # (batch, seq_len, hidden*2)
        context, _ = self.attn(lstm_out)
        last_out = lstm_out[:, -1, :]
        mean_out = torch.mean(lstm_out, dim=1)
        fused = torch.cat([context, last_out, mean_out], dim=1)  # (batch, hidden*2*3)
        logits = self.fc(fused)  # (batch, 1)
        anomaly_prob = self.sigmoid(logits)  # (batch, 1)
        probs = torch.cat([1.0 - anomaly_prob, anomaly_prob], dim=1)
        return probs


def load_model(model_path: str, device: str = "cpu") -> YoloLSTM:
    model = YoloLSTM()
    checkpoint = torch.load(model_path, map_location=device)
    if isinstance(checkpoint, dict) and "state_dict" in checkpoint:
        checkpoint = checkpoint["state_dict"]
    model.load_state_dict(checkpoint, strict=True)
    model.eval()
    return model.to(device)
